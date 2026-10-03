package org.eclipse.cargotracker.interfaces.handling.file;

import java.nio.charset.StandardCharsets;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.batch.api.chunk.listener.SkipReadListener;
import jakarta.batch.runtime.context.JobContext;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

@Dependent
@Named("LineParseExceptionListener")
public class LineParseExceptionListener implements SkipReadListener {

  private static final String S3_BUCKET = "s3_bucket";
  private static final String FAILED_PREFIX = "failed_prefix";

  @Inject private Logger logger;

  @Inject private JobContext jobContext;

  @Override
  public void onSkipReadItem(Exception e) throws Exception {
    String s3Bucket = jobContext.getProperties().getProperty(S3_BUCKET);
    String failedPrefix = jobContext.getProperties().getProperty(FAILED_PREFIX);

    String awsRegion = System.getenv("AWS_REGION");
    if (awsRegion == null || awsRegion.isEmpty()) {
      awsRegion = "us-east-1";
    }
    S3Client s3Client = S3Client.builder()
        .region(Region.of(awsRegion))
        .build();

    EventLineParseException parseException = (EventLineParseException) e;

    logger.log(Level.WARNING, "Problem parsing event file line", parseException);

    String failedObjectKey = failedPrefix + "/failed_"
        + jobContext.getJobName()
        + "_"
        + jobContext.getInstanceId()
        + ".csv";

    StringBuilder failedContent = new StringBuilder();

    // Fetch existing content from S3 if the failed object already exists
    try {
      s3Client.headObject(HeadObjectRequest.builder()
          .bucket(s3Bucket)
          .key(failedObjectKey)
          .build());
      // Object exists — retrieve its current content
      byte[] existingBytes = s3Client.getObjectAsBytes(
          GetObjectRequest.builder()
              .bucket(s3Bucket)
              .key(failedObjectKey)
              .build()).asByteArray();
      failedContent.append(new String(existingBytes, StandardCharsets.UTF_8));
    } catch (NoSuchKeyException ex) {
      // Object does not exist yet — start fresh
    }

    failedContent.append(parseException.getLine()).append(System.lineSeparator());

    // Write the updated content back to S3
    byte[] contentBytes = failedContent.toString().getBytes(StandardCharsets.UTF_8);
    s3Client.putObject(
        PutObjectRequest.builder()
            .bucket(s3Bucket)
            .key(failedObjectKey)
            .contentType("text/csv")
            .contentLength((long) contentBytes.length)
            .build(),
        RequestBody.fromBytes(contentBytes));
  }
}
