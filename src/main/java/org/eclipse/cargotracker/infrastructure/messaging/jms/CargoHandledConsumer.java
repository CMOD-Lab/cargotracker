package org.eclipse.cargotracker.infrastructure.messaging.jms;

import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.cargotracker.application.CargoInspectionService;
import org.eclipse.cargotracker.domain.model.cargo.TrackingId;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageResponse;

/**
 * Consumes Amazon SQS messages and delegates notification of handled cargo to the inspection
 * service.
 *
 * <p>Replaces the JMS {@code @MessageDriven} / {@code MessageListener} pattern with a
 * cloud-native Amazon SQS polling consumer using the AWS SDK for Java v2. The queue URL is
 * resolved from the environment variable {@code CARGO_HANDLED_QUEUE_URL}, following the
 * 12-factor app configuration principle.
 */
@ApplicationScoped
public class CargoHandledConsumer {

  /** Environment variable that holds the SQS queue URL for cargo-handled events. */
  private static final String QUEUE_URL_ENV = "CARGO_HANDLED_QUEUE_URL";

  /** Maximum number of messages to retrieve per poll (SQS maximum is 10). */
  private static final int MAX_NUMBER_OF_MESSAGES = 10;

  /** Long-poll wait time in seconds (reduces empty-response API calls). */
  private static final int WAIT_TIME_SECONDS = 20;

  @Inject private Logger logger;

  @Inject private CargoInspectionService cargoInspectionService;

  @Inject private SqsClient sqsClient;

  private String queueUrl;

  @PostConstruct
  public void init() {
    queueUrl = System.getenv(QUEUE_URL_ENV);
    if (queueUrl == null || queueUrl.isBlank()) {
      logger.log(
          Level.WARNING,
          "Environment variable {0} is not set; CargoHandledConsumer will not poll SQS.",
          QUEUE_URL_ENV);
    } else {
      logger.log(Level.INFO, "CargoHandledConsumer initialised with queue URL: {0}", queueUrl);
    }
  }

  /**
   * Polls the Amazon SQS queue for cargo-handled messages and processes each one.
   *
   * <p>This method is intended to be invoked periodically (e.g., via a scheduled executor or a
   * Jakarta EE {@code @Schedule} timer). Each successfully processed message is deleted from the
   * queue to prevent redelivery.
   */
  public void pollAndProcess() {
    if (queueUrl == null || queueUrl.isBlank()) {
      logger.log(Level.WARNING, "Queue URL is not configured; skipping SQS poll.");
      return;
    }

    ReceiveMessageRequest receiveRequest =
        ReceiveMessageRequest.builder()
            .queueUrl(queueUrl)
            .maxNumberOfMessages(MAX_NUMBER_OF_MESSAGES)
            .waitTimeSeconds(WAIT_TIME_SECONDS)
            .build();

    ReceiveMessageResponse response = sqsClient.receiveMessage(receiveRequest);
    List<Message> messages = response.messages();

    for (Message message : messages) {
      processMessage(message);
    }
  }

  /**
   * Processes a single SQS message: extracts the tracking ID, invokes cargo inspection, and
   * deletes the message from the queue on success.
   *
   * @param message the SQS message to process
   */
  private void processMessage(Message message) {
    try {
      String trackingIdString = message.body();
      logger.log(Level.INFO, "Processing cargo-handled SQS message for tracking ID: {0}", trackingIdString);

      cargoInspectionService.inspectCargo(new TrackingId(trackingIdString));

      // Delete the message from the queue after successful processing
      DeleteMessageRequest deleteRequest =
          DeleteMessageRequest.builder()
              .queueUrl(queueUrl)
              .receiptHandle(message.receiptHandle())
              .build();
      sqsClient.deleteMessage(deleteRequest);

      logger.log(Level.INFO, "Successfully processed and deleted SQS message for tracking ID: {0}", trackingIdString);
    } catch (Exception e) {
      logger.log(Level.SEVERE, "Error processing SQS message: " + message.messageId(), e);
      // Message will become visible again after the visibility timeout expires,
      // allowing for automatic retry by SQS.
    }
  }

  @PreDestroy
  public void cleanup() {
    if (sqsClient != null) {
      sqsClient.close();
      logger.log(Level.INFO, "SqsClient closed for CargoHandledConsumer.");
    }
  }
}
