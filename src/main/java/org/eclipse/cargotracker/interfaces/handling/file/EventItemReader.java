package org.eclipse.cargotracker.interfaces.handling.file;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.Serializable;
import java.time.LocalDateTime;
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
import org.eclipse.cargotracker.application.util.DateConverter;
import org.eclipse.cargotracker.domain.model.cargo.TrackingId;
import org.eclipse.cargotracker.domain.model.handling.HandlingEvent;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import org.eclipse.cargotracker.interfaces.handling.HandlingEventRegistrationAttempt;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Response;
import software.amazon.awssdk.services.s3.model.S3Object;

/**
 * Reads handling event files from Amazon S3 instead of scanning a local directory.
 *
 * <p>Local directory enumeration (e.g. {@code new File(dir).listFiles()}) is incompatible with
 * containerised / cloud environments where the file system is ephemeral and directory structures
 * are not guaranteed. This implementation replaces that pattern with Amazon S3
 * {@code ListObjectsV2} operations, enabling cloud-native resource discovery via prefix-based
 * pagination.
 *
 * <p>Configuration is supplied through Jakarta Batch job properties:
 * <ul>
 *   <li>{@code s3_bucket_name} – the S3 bucket that holds the upload objects. Falls back to the
 *       {@code S3_BUCKET_NAME} environment variable when the job property is absent.</li>
 *   <li>{@code upload_prefix} – the S3 key prefix used to scope the {@code ListObjectsV2} query
 *       (defaults to {@code "uploads/"}).</li>
 * </ul>
 */
@Dependent
@Named("EventItemReader")
public class EventItemReader extends AbstractItemReader {

  /** Job property key for the S3 bucket name. */
  private static final String S3_BUCKET_NAME = "s3_bucket_name";

  /** Environment variable fallback for the S3 bucket name. */
  private static final String S3_BUCKET_NAME_ENV = "S3_BUCKET_NAME";

  /** Job property key for the S3 key prefix used to discover event objects. */
  private static final String UPLOAD_PREFIX = "upload_prefix";

  /** Default S3 key prefix when the job property is not set. */
  private static final String DEFAULT_UPLOAD_PREFIX = "uploads/";

  @Inject private Logger logger;

  @Inject private JobContext jobContext;

  private EventFilesCheckpoint checkpoint;
  private BufferedReader currentReader;
  private String currentObjectKey;

  /** Lazily-initialised S3 client; reused across all readItem() calls within a job step. */
  private S3Client s3Client;

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @Override
  public void open(Serializable checkpoint) throws Exception {
    String bucketName = resolveBucketName();
    String uploadPrefix = jobContext.getProperties().getProperty(UPLOAD_PREFIX, DEFAULT_UPLOAD_PREFIX);

    if (checkpoint == null) {
      this.checkpoint = new EventFilesCheckpoint();
      logger.log(Level.INFO,
          "Scanning S3 bucket for event objects – bucket: {0}, prefix: {1}",
          new Object[]{bucketName, uploadPrefix});

      // Replace local directory scanning with Amazon S3 ListObjectsV2 operations.
      // Pagination is handled so that buckets with more than 1 000 objects are fully enumerated.
      List<String> objectKeys = listS3ObjectsWithPagination(bucketName, uploadPrefix);
      this.checkpoint.setS3ObjectKeys(objectKeys);
    } else {
      logger.log(Level.INFO, "Resuming from previous checkpoint");
      this.checkpoint = (EventFilesCheckpoint) checkpoint;
    }

    currentObjectKey = this.checkpoint.currentS3ObjectKey();

    if (currentObjectKey == null) {
      logger.log(Level.INFO, "No S3 objects found to process under prefix: {0}", uploadPrefix);
      currentReader = null;
    } else {
      openS3Object(bucketName, currentObjectKey);
      logger.log(Level.INFO, "Processing S3 object: s3://{0}/{1}",
          new Object[]{bucketName, currentObjectKey});
      // Restore position within the current object after a checkpoint restart.
      long linesToSkip = this.checkpoint.getFilePointer();
      for (long i = 0; i < linesToSkip; i++) {
        currentReader.readLine();
      }
    }
  }

  @Override
  public Object readItem() throws Exception {
    if (currentReader == null) {
      return null;
    }

    String line = currentReader.readLine();

    if (line != null) {
      this.checkpoint.incrementFilePointer();
      return parseLine(line);
    }

    // Current S3 object exhausted – delete it and advance to the next one.
    String bucketName = resolveBucketName();
    logger.log(Level.INFO,
        "Finished processing S3 object: s3://{0}/{1}",
        new Object[]{bucketName, currentObjectKey});
    currentReader.close();
    deleteS3Object(bucketName, currentObjectKey);

    String nextObjectKey = this.checkpoint.nextS3ObjectKey();
    if (nextObjectKey == null) {
      logger.log(Level.INFO, "No more S3 objects to process");
      currentReader = null;
      return null;
    }

    currentObjectKey = nextObjectKey;
    openS3Object(bucketName, currentObjectKey);
    logger.log(Level.INFO, "Processing S3 object: s3://{0}/{1}",
        new Object[]{bucketName, currentObjectKey});
    return readItem();
  }

  @Override
  public Serializable checkpointInfo() throws Exception {
    return this.checkpoint;
  }

  // -------------------------------------------------------------------------
  // S3 helpers
  // -------------------------------------------------------------------------

  /**
   * Returns the S3 bucket name, preferring the job property and falling back to the
   * {@code S3_BUCKET_NAME} environment variable.
   */
  private String resolveBucketName() {
    String fromProperty = jobContext.getProperties().getProperty(S3_BUCKET_NAME);
    if (fromProperty != null && !fromProperty.isEmpty()) {
      return fromProperty;
    }
    String fromEnv = System.getenv(S3_BUCKET_NAME_ENV);
    if (fromEnv != null && !fromEnv.isEmpty()) {
      return fromEnv;
    }
    throw new IllegalStateException(
        "S3 bucket name is not configured. Set the '" + S3_BUCKET_NAME
            + "' job property or the '" + S3_BUCKET_NAME_ENV + "' environment variable.");
  }

  /**
   * Discovers all S3 objects under the given prefix using {@code ListObjectsV2} with full
   * pagination support. This replaces the previous local {@code File.listFiles()} call.
   *
   * @param bucketName the S3 bucket to query
   * @param prefix     the key prefix that scopes the discovery (analogous to a directory path)
   * @return an ordered list of S3 object keys ready for sequential processing
   */
  private List<String> listS3ObjectsWithPagination(String bucketName, String prefix) {
    List<String> keys = new ArrayList<>();
    String continuationToken = null;

    do {
      ListObjectsV2Request.Builder requestBuilder = ListObjectsV2Request.builder()
          .bucket(bucketName)
          .prefix(prefix);

      if (continuationToken != null) {
        requestBuilder.continuationToken(continuationToken);
      }

      ListObjectsV2Response response = getS3Client().listObjectsV2(requestBuilder.build());

      for (S3Object s3Object : response.contents()) {
        keys.add(s3Object.key());
      }

      continuationToken = response.isTruncated() ? response.nextContinuationToken() : null;

    } while (continuationToken != null);

    logger.log(Level.INFO,
        "ListObjectsV2 discovered {0} S3 object(s) under prefix ''{1}''",
        new Object[]{keys.size(), prefix});
    return keys;
  }

  /**
   * Opens an S3 object for streaming line-by-line reading via a {@link BufferedReader}.
   * No local temporary files are created; the object content is streamed directly from S3.
   */
  private void openS3Object(String bucketName, String objectKey) {
    GetObjectRequest getObjectRequest = GetObjectRequest.builder()
        .bucket(bucketName)
        .key(objectKey)
        .build();
    ResponseInputStream<GetObjectResponse> s3ObjectStream = getS3Client().getObject(getObjectRequest);
    currentReader = new BufferedReader(new InputStreamReader(s3ObjectStream));
  }

  /**
   * Deletes an S3 object after it has been fully processed so that it is not reprocessed on
   * the next scheduler invocation.
   */
  private void deleteS3Object(String bucketName, String objectKey) {
    DeleteObjectRequest deleteRequest = DeleteObjectRequest.builder()
        .bucket(bucketName)
        .key(objectKey)
        .build();
    getS3Client().deleteObject(deleteRequest);
    logger.log(Level.INFO,
        "Deleted processed S3 object: s3://{0}/{1}",
        new Object[]{bucketName, objectKey});
  }

  /** Returns the shared {@link S3Client}, creating it on first use. */
  private S3Client getS3Client() {
    if (s3Client == null) {
      s3Client = S3Client.builder().build();
    }
    return s3Client;
  }

  // -------------------------------------------------------------------------
  // Parsing
  // -------------------------------------------------------------------------

  private Object parseLine(String line) throws EventLineParseException {
    String[] result = line.split(",");

    if (result.length != 5) {
      throw new EventLineParseException("Wrong number of data elements", line);
    }

    LocalDateTime completionTime;
    try {
      completionTime = DateConverter.toDateTime(result[0]);
    } catch (DateTimeParseException e) {
      throw new EventLineParseException("Cannot parse completion time", e, line);
    }

    TrackingId trackingId;
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

    UnLocode unLocode;
    try {
      unLocode = new UnLocode(result[3]);
    } catch (IllegalArgumentException | NullPointerException e) {
      throw new EventLineParseException("Cannot parse UN location code", e, line);
    }

    HandlingEvent.Type eventType;
    try {
      eventType = HandlingEvent.Type.valueOf(result[4]);
    } catch (IllegalArgumentException | NullPointerException e) {
      throw new EventLineParseException("Cannot parse event type", e, line);
    }

    return new HandlingEventRegistrationAttempt(
        LocalDateTime.now(), completionTime, trackingId, voyageNumber, eventType, unLocode);
  }
}
