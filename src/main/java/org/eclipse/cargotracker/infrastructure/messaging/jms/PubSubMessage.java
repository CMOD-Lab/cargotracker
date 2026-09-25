package org.eclipse.cargotracker.infrastructure.messaging.jms;

import java.util.Base64;
import java.util.Map;

/**
 * Represents a Google Cloud Pub/Sub push message payload.
 * Used to deserialize incoming Pub/Sub push notifications.
 */
public class PubSubMessage {

  private Message message;
  private String subscription;

  public Message getMessage() {
    return message;
  }

  public void setMessage(Message message) {
    this.message = message;
  }

  public String getSubscription() {
    return subscription;
  }

  public void setSubscription(String subscription) {
    this.subscription = subscription;
  }

  /**
   * Returns the decoded (Base64) data from the Pub/Sub message.
   */
  public String getDecodedData() {
    if (message != null && message.getData() != null) {
      return new String(Base64.getDecoder().decode(message.getData()));
    }
    return null;
  }

  public static class Message {
    private String data;
    private Map<String, String> attributes;
    private String messageId;
    private String publishTime;

    public String getData() {
      return data;
    }

    public void setData(String data) {
      this.data = data;
    }

    public Map<String, String> getAttributes() {
      return attributes;
    }

    public void setAttributes(Map<String, String> attributes) {
      this.attributes = attributes;
    }

    public String getMessageId() {
      return messageId;
    }

    public void setMessageId(String messageId) {
      this.messageId = messageId;
    }

    public String getPublishTime() {
      return publishTime;
    }

    public void setPublishTime(String publishTime) {
      this.publishTime = publishTime;
    }
  }
}
