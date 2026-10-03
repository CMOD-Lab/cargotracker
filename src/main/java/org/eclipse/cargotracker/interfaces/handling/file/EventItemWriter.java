package org.eclipse.cargotracker.interfaces.handling.file;

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
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

@Dependent
@Named("EventItemWriter")
public class EventItemWriter extends AbstractItemWriter {

  private static final String S3_BUCKET = "s3_bucket";
  private static final String ARCHIVE_PREFIX = "archive_prefix";

  @Inject private JobContext jobContext;
  @Inject private ApplicationEvents applicationEvents;

  private S3Client s3Client;
  private String s3Bucket;
  private String archiveObjectKey;

  @Override
  public void open(Serializable checkpoint) throws Exception {
    s3Bucket = jobContext.getProperties().getProperty(S3_BUCKET);
    String archivePrefix = jobContext.getProperties().getProperty(ARCHIVE_PREFIX);

    String awsRegion = System.getenv("AWS_REGION");
    if (awsRegion == null || awsRegion.isEmpty()) {
      awsRegion = "us-east-1";
    }
    s3Client = S3Client.builder()
        .region(Region.of(awsRegion))
        .build();

    // Build the archive object key using job name and instance ID
    archiveObjectKey = archivePrefix + "/archive_"
        + jobContext.getJobName()
        + "_"
        + jobContext.getInstanceId()
        + ".csv";
  }

  @Override
  @Transactional
  public void writeItems(List<Object> items) throws Exception {
    StringBuilder archiveContent = new StringBuilder();

    // Fetch existing content from S3 if the archive object already exists
    try {
      s3Client.headObject(HeadObjectRequest.builder()
          .bucket(s3Bucket)
          .key(archiveObjectKey)
          .build());
      // Object exists — retrieve its current content
      byte[] existingBytes = s3Client.getObjectAsBytes(
          GetObjectRequest.builder()
              .bucket(s3Bucket)
              .key(archiveObjectKey)
              .build()).asByteArray();
      archiveContent.append(new String(existingBytes, StandardCharsets.UTF_8));
    } catch (NoSuchKeyException e) {
      // Object does not exist yet — start fresh
    }

    items.stream()
        .map(item -> (HandlingEventRegistrationAttempt) item)
        .forEach(attempt -> {
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

    // Write the updated content back to S3
    byte[] contentBytes = archiveContent.toString().getBytes(StandardCharsets.UTF_8);
    s3Client.putObject(
        PutObjectRequest.builder()
            .bucket(s3Bucket)
            .key(archiveObjectKey)
            .contentType("text/csv")
            .contentLength((long) contentBytes.length)
            .build(),
        RequestBody.fromBytes(contentBytes));
  }
}
