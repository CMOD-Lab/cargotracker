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
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Response;
import software.amazon.awssdk.services.s3.model.S3Object;

@Dependent
@Named("EventItemReader")
public class EventItemReader extends AbstractItemReader {

  private static final String S3_BUCKET = "s3_bucket";
  private static final String UPLOAD_PREFIX = "upload_prefix";

  @Inject private Logger logger;

  @Inject private JobContext jobContext;
  private EventFilesCheckpoint checkpoint;
  private S3Client s3Client;
  private BufferedReader currentReader;
  private String currentObjectKey;

  @Override
  public void open(Serializable checkpoint) throws Exception {
    String s3Bucket = jobContext.getProperties().getProperty(S3_BUCKET);
    String uploadPrefix = jobContext.getProperties().getProperty(UPLOAD_PREFIX);

    String awsRegion = System.getenv("AWS_REGION");
    if (awsRegion == null || awsRegion.isEmpty()) {
      awsRegion = "us-east-1";
    }
    s3Client = S3Client.builder()
        .region(Region.of(awsRegion))
        .build();

    if (checkpoint == null) {
      this.checkpoint = new EventFilesCheckpoint();
      logger.log(Level.INFO, "Scanning S3 upload prefix: s3://{0}/{1}", new Object[]{s3Bucket, uploadPrefix});

      List<String> objectKeys = listS3Objects(s3Bucket, uploadPrefix);
      if (objectKeys.isEmpty()) {
        logger.log(Level.INFO, "No files found in S3 upload prefix");
      } else {
        this.checkpoint.setObjectKeys(objectKeys);
      }
    } else {
      logger.log(Level.INFO, "Starting from previous checkpoint");
      this.checkpoint = (EventFilesCheckpoint) checkpoint;
    }

    currentObjectKey = this.checkpoint.currentObjectKey();

    if (currentObjectKey == null) {
      logger.log(Level.INFO, "No files to process");
      currentReader = null;
    } else {
      currentReader = openS3Object(s3Bucket, currentObjectKey);
      logger.log(Level.INFO, "Processing S3 object: {0}", currentObjectKey);
      // Seek to the checkpoint position by skipping already-read lines
      long linesToSkip = this.checkpoint.getFilePointer();
      for (long i = 0; i < linesToSkip; i++) {
        if (currentReader.readLine() == null) {
          break;
        }
      }
    }
  }

  private List<String> listS3Objects(String bucket, String prefix) {
    List<String> keys = new ArrayList<>();
    ListObjectsV2Request request = ListObjectsV2Request.builder()
        .bucket(bucket)
        .prefix(prefix)
        .build();
    ListObjectsV2Response response = s3Client.listObjectsV2(request);
    for (S3Object s3Object : response.contents()) {
      // Only include actual files (not prefix "directories")
      if (!s3Object.key().endsWith("/")) {
        keys.add(s3Object.key());
      }
    }
    return keys;
  }

  private BufferedReader openS3Object(String bucket, String key) {
    GetObjectRequest getObjectRequest = GetObjectRequest.builder()
        .bucket(bucket)
        .key(key)
        .build();
    ResponseInputStream<GetObjectResponse> s3Object = s3Client.getObject(getObjectRequest);
    return new BufferedReader(new InputStreamReader(s3Object));
  }

  @Override
  public Object readItem() throws Exception {
    if (currentReader != null) {
      String line = currentReader.readLine();

      if (line != null) {
        this.checkpoint.incrementFilePointer();
        return parseLine(line);
      } else {
        String s3Bucket = jobContext.getProperties().getProperty(S3_BUCKET);
        logger.log(Level.INFO, "Finished processing S3 object, deleting: {0}", currentObjectKey);
        currentReader.close();
        // Delete the processed object from S3
        s3Client.deleteObject(DeleteObjectRequest.builder()
            .bucket(s3Bucket)
            .key(currentObjectKey)
            .build());

        String nextKey = this.checkpoint.nextObjectKey();

        if (nextKey == null) {
          logger.log(Level.INFO, "No more files to process");
          return null;
        } else {
          currentObjectKey = nextKey;
          currentReader = openS3Object(s3Bucket, currentObjectKey);
          logger.log(Level.INFO, "Processing S3 object: {0}", currentObjectKey);
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

    HandlingEventRegistrationAttempt attempt =
        new HandlingEventRegistrationAttempt(
            LocalDateTime.now(), completionTime, trackingId, voyageNumber, eventType, unLocode);

    return attempt;
  }

  @Override
  public Serializable checkpointInfo() throws Exception {
    return this.checkpoint;
  }
}
