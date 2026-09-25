package org.eclipse.cargotracker.interfaces.handling.file;

import java.io.ByteArrayOutputStream;
import java.io.PrintWriter;
import java.io.Serializable;
import java.nio.charset.StandardCharsets;
import java.util.List;
import jakarta.batch.api.chunk.AbstractItemWriter;
import jakarta.batch.runtime.context.JobContext;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.transaction.Transactional;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;
import org.eclipse.cargotracker.application.ApplicationEvents;
import org.eclipse.cargotracker.application.util.DateConverter;
import org.eclipse.cargotracker.interfaces.handling.HandlingEventRegistrationAttempt;

/**
 * Writes processed handling event records to Google Cloud Storage instead of local file system.
 * Replaces hard-coded file paths and java.io.File usage with GCS SDK operations.
 */
@Dependent
@Named("EventItemWriter")
public class EventItemWriter extends AbstractItemWriter {

  private static final String GCS_BUCKET_NAME_PROPERTY = "gcs_bucket_name";
  private static final String ARCHIVE_PREFIX_PROPERTY = "archive_prefix";
  private static final String DEFAULT_ARCHIVE_PREFIX = "archive/";

  @Inject private JobContext jobContext;
  @Inject private ApplicationEvents applicationEvents;

  private Storage storage;
  private String bucketName;
  private String archivePrefix;

  @Override
  public void open(Serializable checkpoint) throws Exception {
    storage = StorageOptions.getDefaultInstance().getService();
    bucketName = jobContext.getProperties().getProperty(GCS_BUCKET_NAME_PROPERTY,
        System.getenv().getOrDefault("GCS_BUCKET_NAME", "cargo-tracker-uploads"));
    archivePrefix = jobContext.getProperties().getProperty(ARCHIVE_PREFIX_PROPERTY,
        DEFAULT_ARCHIVE_PREFIX);
  }

  @Override
  @Transactional
  public void writeItems(List<Object> items) throws Exception {
    String archiveBlobName = archivePrefix
        + "archive_"
        + jobContext.getJobName()
        + "_"
        + jobContext.getInstanceId()
        + ".csv";

    // Build CSV content in memory
    ByteArrayOutputStream baos = new ByteArrayOutputStream();
    try (PrintWriter archive = new PrintWriter(baos, true, StandardCharsets.UTF_8)) {
      items
          .stream()
          .map(item -> (HandlingEventRegistrationAttempt) item)
          .forEach(
              attempt -> {
                applicationEvents.receivedHandlingEventRegistrationAttempt(attempt);
                archive.println(
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
                        + attempt.getType());
              });
    }

    // Write to GCS using durable cloud storage
    BlobId blobId = BlobId.of(bucketName, archiveBlobName);
    BlobInfo blobInfo = BlobInfo.newBuilder(blobId)
        .setContentType("text/csv")
        .build();
    storage.create(blobInfo, baos.toByteArray());
  }
}
