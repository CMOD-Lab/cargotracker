package org.eclipse.cargotracker.infrastructure.messaging.jms;

import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import jakarta.annotation.Resource;
import jakarta.enterprise.concurrent.ManagedExecutorService;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageResponse;

/**
 * Consumes Amazon SQS messages for delivered cargo events.
 *
 * <p>Replaces the JMS {@code @MessageDriven} MDB with a cloud-native SQS polling consumer.
 * The queue URL is resolved from the environment variable {@code DELIVERED_CARGO_QUEUE_URL}.
 */
@ApplicationScoped
public class DeliveredCargoConsumer {

  private static final String QUEUE_URL_ENV = "DELIVERED_CARGO_QUEUE_URL";
  private static final int MAX_MESSAGES = 10;
  private static final int WAIT_TIME_SECONDS = 20;

  @Inject private Logger logger;

  @Inject private SqsClient sqsClient;

  @Resource private ManagedExecutorService executorService;

  private volatile boolean running = false;
  private String queueUrl;

  @PostConstruct
  public void init() {
    queueUrl = System.getenv(QUEUE_URL_ENV);
    if (queueUrl == null || queueUrl.isBlank()) {
      logger.log(
          Level.WARNING,
          "Environment variable {0} is not set; DeliveredCargoConsumer will not poll SQS.",
          QUEUE_URL_ENV);
      return;
    }
    running = true;
    executorService.submit(this::pollMessages);
    logger.log(Level.INFO, "DeliveredCargoConsumer started polling SQS queue: {0}", queueUrl);
  }

  @PreDestroy
  public void shutdown() {
    running = false;
    logger.log(Level.INFO, "DeliveredCargoConsumer shutting down.");
  }

  private void pollMessages() {
    while (running) {
      try {
        ReceiveMessageRequest receiveRequest =
            ReceiveMessageRequest.builder()
                .queueUrl(queueUrl)
                .maxNumberOfMessages(MAX_MESSAGES)
                .waitTimeSeconds(WAIT_TIME_SECONDS)
                .build();

        ReceiveMessageResponse response = sqsClient.receiveMessage(receiveRequest);
        List<Message> messages = response.messages();

        for (Message message : messages) {
          processMessage(message);
        }
      } catch (Exception e) {
        if (running) {
          logger.log(Level.SEVERE, "Error polling SQS queue for DeliveredCargoConsumer", e);
        }
      }
    }
  }

  private void processMessage(Message message) {
    try {
      logger.log(Level.INFO, "Cargo with tracking ID {0} delivered.", message.body());

      // Delete the message from the queue after successful processing
      DeleteMessageRequest deleteRequest =
          DeleteMessageRequest.builder()
              .queueUrl(queueUrl)
              .receiptHandle(message.receiptHandle())
              .build();
      sqsClient.deleteMessage(deleteRequest);
    } catch (Exception ex) {
      logger.log(Level.WARNING, "Error processing SQS message in DeliveredCargoConsumer.", ex);
    }
  }
}
