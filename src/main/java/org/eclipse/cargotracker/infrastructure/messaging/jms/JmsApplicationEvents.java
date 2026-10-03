package org.eclipse.cargotracker.infrastructure.messaging.jms;

import java.io.Serializable;
import java.time.format.DateTimeFormatter;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.cargotracker.application.ApplicationEvents;
import org.eclipse.cargotracker.domain.model.cargo.Cargo;
import org.eclipse.cargotracker.domain.model.handling.HandlingEvent;
import org.eclipse.cargotracker.interfaces.handling.HandlingEventRegistrationAttempt;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.MessageAttributeValue;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

/**
 * Amazon SQS-based implementation of {@link ApplicationEvents}.
 *
 * <p>Replaces the JMS-based {@code JmsApplicationEvents} with a cloud-native SQS producer.
 * Queue URLs are resolved from environment variables:
 * <ul>
 *   <li>{@code CARGO_HANDLED_QUEUE_URL}</li>
 *   <li>{@code MISDIRECTED_CARGO_QUEUE_URL}</li>
 *   <li>{@code DELIVERED_CARGO_QUEUE_URL}</li>
 *   <li>{@code HANDLING_EVENT_REGISTRATION_ATTEMPT_QUEUE_URL}</li>
 * </ul>
 */
@ApplicationScoped
public class JmsApplicationEvents implements ApplicationEvents, Serializable {

  private static final long serialVersionUID = 1L;
  private static final DateTimeFormatter FORMATTER = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

  @Inject private Logger logger;

  @Inject private SqsClient sqsClient;

  @Override
  public void cargoWasHandled(HandlingEvent event) {
    Cargo cargo = event.getCargo();
    logger.log(Level.INFO, "Cargo was handled {0}", cargo);
    String queueUrl = System.getenv("CARGO_HANDLED_QUEUE_URL");
    if (queueUrl == null || queueUrl.isBlank()) {
      logger.log(Level.WARNING, "CARGO_HANDLED_QUEUE_URL is not set; skipping SQS send.");
      return;
    }
    sendTextMessage(queueUrl, cargo.getTrackingId().getIdString());
  }

  @Override
  public void cargoWasMisdirected(Cargo cargo) {
    logger.log(Level.INFO, "Cargo was misdirected {0}", cargo);
    String queueUrl = System.getenv("MISDIRECTED_CARGO_QUEUE_URL");
    if (queueUrl == null || queueUrl.isBlank()) {
      logger.log(Level.WARNING, "MISDIRECTED_CARGO_QUEUE_URL is not set; skipping SQS send.");
      return;
    }
    sendTextMessage(queueUrl, cargo.getTrackingId().getIdString());
  }

  @Override
  public void cargoHasArrived(Cargo cargo) {
    logger.log(Level.INFO, "Cargo has arrived {0}", cargo);
    String queueUrl = System.getenv("DELIVERED_CARGO_QUEUE_URL");
    if (queueUrl == null || queueUrl.isBlank()) {
      logger.log(Level.WARNING, "DELIVERED_CARGO_QUEUE_URL is not set; skipping SQS send.");
      return;
    }
    sendTextMessage(queueUrl, cargo.getTrackingId().getIdString());
  }

  @Override
  public void receivedHandlingEventRegistrationAttempt(HandlingEventRegistrationAttempt attempt) {
    logger.log(Level.INFO, "Received handling event registration attempt {0}", attempt);
    String queueUrl = System.getenv("HANDLING_EVENT_REGISTRATION_ATTEMPT_QUEUE_URL");
    if (queueUrl == null || queueUrl.isBlank()) {
      logger.log(
          Level.WARNING,
          "HANDLING_EVENT_REGISTRATION_ATTEMPT_QUEUE_URL is not set; skipping SQS send.");
      return;
    }
    sendAttemptMessage(queueUrl, attempt);
  }

  private void sendTextMessage(String queueUrl, String messageBody) {
    try {
      SendMessageRequest request =
          SendMessageRequest.builder()
              .queueUrl(queueUrl)
              .messageBody(messageBody)
              .build();
      sqsClient.sendMessage(request);
    } catch (Exception e) {
      logger.log(Level.SEVERE, "Failed to send SQS message to queue: " + queueUrl, e);
    }
  }

  private void sendAttemptMessage(String queueUrl, HandlingEventRegistrationAttempt attempt) {
    try {
      // Encode attempt fields as SQS message attributes for structured deserialization
      String voyageNumber =
          attempt.getVoyageNumber() != null ? attempt.getVoyageNumber().getIdString() : "";

      SendMessageRequest request =
          SendMessageRequest.builder()
              .queueUrl(queueUrl)
              .messageBody(attempt.getTrackingId().getIdString())
              .messageAttributes(
                  java.util.Map.of(
                      "completionTime",
                      stringAttr(attempt.getCompletionTime().format(FORMATTER)),
                      "trackingId",
                      stringAttr(attempt.getTrackingId().getIdString()),
                      "voyageNumber",
                      stringAttr(voyageNumber),
                      "unLocode",
                      stringAttr(attempt.getUnLocode().getIdString()),
                      "eventType",
                      stringAttr(attempt.getType().name())))
              .build();
      sqsClient.sendMessage(request);
    } catch (Exception e) {
      logger.log(
          Level.SEVERE,
          "Failed to send handling event registration attempt SQS message to queue: " + queueUrl,
          e);
    }
  }

  private MessageAttributeValue stringAttr(String value) {
    return MessageAttributeValue.builder()
        .dataType("String")
        .stringValue(value != null ? value : "")
        .build();
  }
}
