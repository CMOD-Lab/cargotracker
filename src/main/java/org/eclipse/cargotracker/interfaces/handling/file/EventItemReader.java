package org.eclipse.cargotracker.interfaces.handling.file;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.Serializable;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.batch.api.chunk.AbstractItemReader;
import jakarta.batch.runtime.context.JobContext;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import com.google.cloud.storage.Blob;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;
import org.eclipse.cargotracker.application.util.DateConverter;
import org.eclipse.cargotracker.domain.model.cargo.TrackingId;
import org.eclipse.cargotracker.domain.model.handling.HandlingEvent;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import org.eclipse.cargotracker.interfaces.handling.HandlingEventRegistrationAttempt;

/**
 * Reads handling event files from Google Cloud Storage instead of local file system.
 * Replaces hard-coded file paths and java.io.File usage with GCS SDK operations.
 */
@Dependent
@Named("EventItemReader")
public class EventItemReader extends AbstractItemReader {

  private static final String GCS_BUCKET_NAME_PROPERTY = "gcs_bucket_name";
  private static final String UPLOAD_PREFIX_PROPERTY = "upload_prefix";
  private static final String DEFAULT_UPLOAD_PREFIX = "upload/";

  @Inject private Logger logger;

  @Inject private JobContext jobContext;
  private EventFilesCheckpoint checkpoint;
  private BufferedReader currentReader;
  private List<String> pendingBlobNames;
  private int currentBlobIndex;
  private Storage storage;

  @Override
  public void open(Serializable checkpoint) throws Exception {
    storage = StorageOptions.getDefaultInstance().getService();
    String bucketName = jobContext.getProperties().getProperty(GCS_BUCKET_NAME_PROPERTY,
        System.getenv().getOrDefault("GCS_BUCKET_NAME", "cargo-tracker-uploads"));
    String uploadPrefix = jobContext.getProperties().getProperty(UPLOAD_PREFIX_PROPERTY,
        DEFAULT_UPLOAD_PREFIX);

    if (checkpoint == null) {
      this.checkpoint = new EventFilesCheckpoint();
      logger.log(Level.INFO, "Scanning GCS bucket: {0} with prefix: {1}",
          new Object[]{bucketName, uploadPrefix});

      pendingBlobNames = new ArrayList<>();
      for (Blob blob : storage.list(bucketName,
          Storage.BlobListOption.prefix(uploadPrefix)).iterateAll()) {
        if (!blob.isDirectory()) {
          pendingBlobNames.add(blob.getName());
        }
      }
      currentBlobIndex = 0;
      logger.log(Level.INFO, "Found {0} files to process in GCS", pendingBlobNames.size());
    } else {
      logger.log(Level.INFO, "Starting from previous checkpoint");
      this.checkpoint = (EventFilesCheckpoint) checkpoint;
      pendingBlobNames = new ArrayList<>();
      for (Blob blob : storage.list(bucketName,
          Storage.BlobListOption.prefix(uploadPrefix)).iterateAll()) {
        if (!blob.isDirectory()) {
          pendingBlobNames.add(blob.getName());
        }
      }
      currentBlobIndex = 0;
    }

    openNextBlob(bucketName);
  }

  private void openNextBlob(String bucketName) throws Exception {
    if (currentBlobIndex < pendingBlobNames.size()) {
      String blobName = pendingBlobNames.get(currentBlobIndex);
      Blob blob = storage.get(bucketName, blobName);
      if (blob != null) {
        currentReader = new BufferedReader(
            new InputStreamReader(
                new java.io.ByteArrayInputStream(blob.getContent()),
                StandardCharsets.UTF_8));
        logger.log(Level.INFO, "Processing GCS object: {0}", blobName);
      } else {
        currentReader = null;
        currentBlobIndex++;
        openNextBlob(bucketName);
      }
    } else {
      currentReader = null;
    }
  }

  @Override
  public Object readItem() throws Exception {
    if (currentReader != null) {
      String line = currentReader.readLine();

      if (line != null) {
        return parseLine(line);
      } else {
        currentReader.close();
        String processedBlobName = pendingBlobNames.get(currentBlobIndex);
        logger.log(Level.INFO, "Finished processing GCS object: {0}", processedBlobName);

        // Delete processed blob from GCS
        String bucketName = jobContext.getProperties().getProperty(GCS_BUCKET_NAME_PROPERTY,
            System.getenv().getOrDefault("GCS_BUCKET_NAME", "cargo-tracker-uploads"));
        storage.delete(bucketName, processedBlobName);

        currentBlobIndex++;
        openNextBlob(bucketName);

        if (currentReader == null) {
          logger.log(Level.INFO, "No more GCS objects to process");
          return null;
        } else {
          return readItem();
        }
      }
    } else {
      return null;
    }
  }

  private Object parseLine(String line) throws EventLineParseException {
    String[] result = line.split(",");

    if (result.length != 5) {
      throw new EventLineParseException("Wrong number of data elements", line);
    }

    LocalDateTime completionTime = null;

    try {
      completionTime = DateConverter.toDateTime(result[0]);
    } catch (DateTimeParseException e) {
      throw new EventLineParseException("Cannot parse completion time", e, line);
    }

    TrackingId trackingId = null;

    try {
      trackingId = new TrackingId(result[1]);
    } catch (NullPointerException e) {
      throw new EventLineParseException("Cannot parse tracking ID", e, line);
    }

    VoyageNumber voyageNumber = null;

    try {
      if (!result[2].isEmpty()) {
        voyageNumber = new VoyageNumber(result[2]);
      }
    } catch (NullPointerException e) {
      throw new EventLineParseException("Cannot parse voyage number", e, line);
    }

    UnLocode unLocode = null;

    try {
      unLocode = new UnLocode(result[3]);
    } catch (IllegalArgumentException | NullPointerException e) {
      throw new EventLineParseException("Cannot parse UN location code", e, line);
    }

    HandlingEvent.Type eventType = null;

    try {
      eventType = HandlingEvent.Type.valueOf(result[4]);
    } catch (IllegalArgumentException | NullPointerException e) {
      throw new EventLineParseException("Cannot parse event type", e, line);
    }

    // Use UTC-based timestamp for cloud-native time handling
    HandlingEventRegistrationAttempt attempt =
        new HandlingEventRegistrationAttempt(
            LocalDateTime.now(ZoneOffset.UTC), completionTime, trackingId, voyageNumber,
            eventType, unLocode);

    return attempt;
  }

  @Override
  public Serializable checkpointInfo() throws Exception {
    return this.checkpoint;
  }
}
