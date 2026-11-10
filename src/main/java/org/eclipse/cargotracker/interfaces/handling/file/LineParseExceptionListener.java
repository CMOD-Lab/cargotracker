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
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

@Dependent
@Named("LineParseExceptionListener")
public class LineParseExceptionListener implements SkipReadListener {

  private static final String S3_BUCKET_NAME = "s3_bucket_name";
  private static final String FAILED_PREFIX = "failed_prefix";

  @Inject private Logger logger;

  @Inject private JobContext jobContext;

  private S3Client s3Client;

  private S3Client getS3Client() {
    if (s3Client == null) {
      s3Client = S3Client.builder().build();
    }
    return s3Client;
  }

  @Override
  public void onSkipReadItem(Exception e) throws Exception {
    String bucketName = jobContext.getProperties().getProperty(S3_BUCKET_NAME);
    String failedPrefix = jobContext.getProperties().getProperty(FAILED_PREFIX, "failed/");

    EventLineParseException parseException = (EventLineParseException) e;

    logger.log(Level.WARNING, "Problem parsing event file line", parseException);

    String failedKey = failedPrefix
        + "failed_"
        + jobContext.getJobName()
        + "_"
        + jobContext.getInstanceId()
        + ".csv";

    byte[] contentBytes = (parseException.getLine() + System.lineSeparator())
        .getBytes(StandardCharsets.UTF_8);

    PutObjectRequest putRequest = PutObjectRequest.builder()
        .bucket(bucketName)
        .key(failedKey)
        .contentType("text/csv")
        .build();
    getS3Client().putObject(putRequest, RequestBody.fromBytes(contentBytes));

    logger.log(Level.INFO, "Written failed line to S3: s3://{0}/{1}",
        new Object[]{bucketName, failedKey});
  }
}
