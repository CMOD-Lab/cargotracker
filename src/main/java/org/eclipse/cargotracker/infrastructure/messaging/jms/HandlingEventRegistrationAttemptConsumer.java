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
import org.eclipse.cargotracker.application.HandlingEventService;
import org.eclipse.cargotracker.domain.model.cargo.TrackingId;
import org.eclipse.cargotracker.domain.model.handling.CannotCreateHandlingEventException;
import org.eclipse.cargotracker.domain.model.handling.HandlingEvent;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest;
import software.amazon.awssdk.services.sqs.model.Message;
import software.amazon.awssdk.services.sqs.model.MessageAttributeValue;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageResponse;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;

/**
 * Consumes Amazon SQS messages for handling event registration attempts and delegates to the
 * handling event service.
 *
 * <p>Replaces the JMS {@code @MessageDriven} MDB with a cloud-native SQS polling consumer.
 * The queue URL is resolved from the environment variable
 * {@code HANDLING_EVENT_REGISTRATION_ATTEMPT_QUEUE_URL}.
 */
@ApplicationScoped
public class HandlingEventRegistrationAttemptConsumer {

  private static final String QUEUE_URL_ENV = "HANDLING_EVENT_REGISTRATION_ATTEMPT_QUEUE_URL";
  private static final int MAX_MESSAGES = 10;
  private static final int WAIT_TIME_SECONDS = 20;
  private static final DateTimeFormatter FORMATTER = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

  @Inject private Logger logger;

  @Inject private HandlingEventService handlingEventService;

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
          "Environment variable {0} is not set; HandlingEventRegistrationAttemptConsumer will not poll SQS.",
          QUEUE_URL_ENV);
      return;
    }
    running = true;
    executorService.submit(this::pollMessages);
    logger.log(
        Level.INFO,
        "HandlingEventRegistrationAttemptConsumer started polling SQS queue: {0}",
        queueUrl);
  }

  @PreDestroy
  public void shutdown() {
    running = false;
    logger.log(Level.INFO, "HandlingEventRegistrationAttemptConsumer shutting down.");
  }

  private void pollMessages() {
    while (running) {
      try {
        ReceiveMessageRequest receiveRequest =
            ReceiveMessageRequest.builder()
                .queueUrl(queueUrl)
                .maxNumberOfMessages(MAX_MESSAGES)
                .waitTimeSeconds(WAIT_TIME_SECONDS)
                .messageAttributeNames("All")
                .build();

        ReceiveMessageResponse response = sqsClient.receiveMessage(receiveRequest);
        List<Message> messages = response.messages();

        for (Message message : messages) {
          processMessage(message);
        }
      } catch (Exception e) {
        if (running) {
          logger.log(
              Level.SEVERE,
              "Error polling SQS queue for HandlingEventRegistrationAttemptConsumer",
              e);
        }
      }
    }
  }

  private void processMessage(Message message) {
    try {
      Map<String, MessageAttributeValue> attrs = message.messageAttributes();

      LocalDateTime completionTime =
          LocalDateTime.parse(getAttributeValue(attrs, "completionTime"), FORMATTER);
      TrackingId trackingId = new TrackingId(getAttributeValue(attrs, "trackingId"));
      String voyageNumberStr = getAttributeValue(attrs, "voyageNumber");
      VoyageNumber voyageNumber =
          (voyageNumberStr != null && !voyageNumberStr.isBlank())
              ? new VoyageNumber(voyageNumberStr)
              : null;
      UnLocode unLocode = new UnLocode(getAttributeValue(attrs, "unLocode"));
      HandlingEvent.Type type =
          HandlingEvent.Type.valueOf(getAttributeValue(attrs, "eventType"));

      handlingEventService.registerHandlingEvent(
          completionTime, trackingId, voyageNumber, unLocode, type);

      // Delete the message from the queue after successful processing
      DeleteMessageRequest deleteRequest =
          DeleteMessageRequest.builder()
              .queueUrl(queueUrl)
              .receiptHandle(message.receiptHandle())
              .build();
      sqsClient.deleteMessage(deleteRequest);

      logger.log(
          Level.INFO,
          "Successfully processed handling event registration attempt for tracking ID: {0}",
          trackingId);
    } catch (CannotCreateHandlingEventException e) {
      // Poison messages: log and delete to avoid infinite retry
      logger.log(Level.SEVERE, "Cannot create handling event from SQS message; discarding.", e);
      deleteMessageSilently(message);
    } catch (Exception e) {
      logger.log(
          Level.SEVERE,
          "Error processing SQS message in HandlingEventRegistrationAttemptConsumer",
          e);
      // Message will become visible again after visibility timeout for retry
    }
  }

  private String getAttributeValue(
      Map<String, MessageAttributeValue> attrs, String key) {
    MessageAttributeValue attr = attrs.get(key);
    return attr != null ? attr.stringValue() : null;
  }

  private void deleteMessageSilently(Message message) {
    try {
      sqsClient.deleteMessage(
          DeleteMessageRequest.builder()
              .queueUrl(queueUrl)
              .receiptHandle(message.receiptHandle())
              .build());
    } catch (Exception ex) {
      logger.log(Level.WARNING, "Failed to delete poison message from SQS queue.", ex);
    }
  }
}
