package org.eclipse.cargotracker.interfaces.handling.file;

import java.io.ByteArrayOutputStream;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.batch.api.chunk.listener.SkipReadListener;
import jakarta.batch.runtime.context.JobContext;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;

/**
 * Writes failed parse records to Google Cloud Storage instead of local file system.
 * Replaces hard-coded file paths and java.io.File usage with GCS SDK operations.
 */
@Dependent
@Named("LineParseExceptionListener")
public class LineParseExceptionListener implements SkipReadListener {

  private static final String GCS_BUCKET_NAME_PROPERTY = "gcs_bucket_name";
  private static final String FAILED_PREFIX_PROPERTY = "failed_prefix";
  private static final String DEFAULT_FAILED_PREFIX = "failed/";

  @Inject private Logger logger;

  @Inject private JobContext jobContext;

  @Override
  public void onSkipReadItem(Exception e) throws Exception {
    String bucketName = jobContext.getProperties().getProperty(GCS_BUCKET_NAME_PROPERTY,
        System.getenv().getOrDefault("GCS_BUCKET_NAME", "cargo-tracker-uploads"));
    String failedPrefix = jobContext.getProperties().getProperty(FAILED_PREFIX_PROPERTY,
        DEFAULT_FAILED_PREFIX);

    EventLineParseException parseException = (EventLineParseException) e;

    logger.log(Level.WARNING, "Problem parsing event file line", parseException);

    String failedBlobName = failedPrefix
        + "failed_"
        + jobContext.getJobName()
        + "_"
        + jobContext.getInstanceId()
        + ".csv";

    // Build failed record content
    ByteArrayOutputStream baos = new ByteArrayOutputStream();
    try (PrintWriter failed = new PrintWriter(baos, true, StandardCharsets.UTF_8)) {
      failed.println(parseException.getLine());
    }

    // Write to GCS using durable cloud storage
    Storage storage = StorageOptions.getDefaultInstance().getService();
    BlobId blobId = BlobId.of(bucketName, failedBlobName);
    BlobInfo blobInfo = BlobInfo.newBuilder(blobId)
        .setContentType("text/csv")
        .build();
    storage.create(blobInfo, baos.toByteArray());
  }
}
