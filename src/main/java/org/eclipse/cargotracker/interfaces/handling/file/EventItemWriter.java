package org.eclipse.cargotracker.interfaces.handling.file;

import java.io.ByteArrayInputStream;
import java.io.Serializable;
import java.nio.charset.StandardCharsets;
import java.util.List;
import jakarta.batch.api.chunk.AbstractItemWriter;
import jakarta.batch.runtime.context.JobContext;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.transaction.Transactional;
import org.eclipse.cargotracker.application.ApplicationEvents;
import org.eclipse.cargotracker.application.util.DateConverter;
import org.eclipse.cargotracker.interfaces.handling.HandlingEventRegistrationAttempt;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

@Dependent
@Named("EventItemWriter")
public class EventItemWriter extends AbstractItemWriter {

  private static final String S3_BUCKET_NAME = "s3_bucket_name";
  private static final String ARCHIVE_PREFIX = "archive_prefix";

  @Inject private JobContext jobContext;
  @Inject private ApplicationEvents applicationEvents;

  private S3Client s3Client;

  private S3Client getS3Client() {
    if (s3Client == null) {
      s3Client = S3Client.builder().build();
    }
    return s3Client;
  }

  @Override
  public void open(Serializable checkpoint) throws Exception {
    // No local directory setup needed; S3 bucket is used for archiving
    String bucketName = jobContext.getProperties().getProperty(S3_BUCKET_NAME);
    String archivePrefix = jobContext.getProperties().getProperty(ARCHIVE_PREFIX, "archive/");
    // Validate that required S3 properties are configured
    if (bucketName == null || bucketName.isEmpty()) {
      throw new IllegalStateException(
          "S3 bucket name must be configured via job property '" + S3_BUCKET_NAME + "'");
    }
  }

  @Override
  @Transactional
  public void writeItems(List<Object> items) throws Exception {
    String bucketName = jobContext.getProperties().getProperty(S3_BUCKET_NAME);
    String archivePrefix = jobContext.getProperties().getProperty(ARCHIVE_PREFIX, "archive/");
    String archiveKey = archivePrefix
        + "archive_"
        + jobContext.getJobName()
        + "_"
        + jobContext.getInstanceId()
        + ".csv";

    StringBuilder archiveContent = new StringBuilder();

    items
        .stream()
        .map(item -> (HandlingEventRegistrationAttempt) item)
        .forEach(
            attempt -> {
              applicationEvents.receivedHandlingEventRegistrationAttempt(attempt);
              archiveContent.append(
                  DateConverter.toString(attempt.getRegistrationTime())
                      + ","
                      + DateConverter.toString(attempt.getCompletionTime())
                      + ","
                      + attempt.getTrackingId()
                      + ","
                      + attempt.getVoyageNumber()
                      + ","
                      + attempt.getUnLocode()
                      + ","
                      + attempt.getType()
                      + System.lineSeparator());
            });

    byte[] contentBytes = archiveContent.toString().getBytes(StandardCharsets.UTF_8);
    PutObjectRequest putRequest = PutObjectRequest.builder()
        .bucket(bucketName)
        .key(archiveKey)
        .contentType("text/csv")
        .build();
    getS3Client().putObject(putRequest, RequestBody.fromBytes(contentBytes));
  }
}
