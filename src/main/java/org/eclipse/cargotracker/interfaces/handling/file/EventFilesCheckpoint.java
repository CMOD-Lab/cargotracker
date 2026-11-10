package org.eclipse.cargotracker.interfaces.handling.file;

import java.io.Serializable;
import java.util.LinkedList;
import java.util.List;

public class EventFilesCheckpoint implements Serializable {

  private static final long serialVersionUID = 1L;

  private List<String> s3ObjectKeys = new LinkedList<>();
  private int fileIndex = 0;
  private long filePointer = 0;

  public void setS3ObjectKeys(List<String> s3ObjectKeys) {
    this.s3ObjectKeys = s3ObjectKeys;
  }

  public long getFilePointer() {
    return filePointer;
  }

  public void setFilePointer(long filePointer) {
    this.filePointer = filePointer;
  }

  public void incrementFilePointer() {
    this.filePointer++;
  }

  public String currentS3ObjectKey() {
    if (s3ObjectKeys.size() > fileIndex) {
      return s3ObjectKeys.get(fileIndex);
    } else {
      return null;
    }
  }

  public String nextS3ObjectKey() {
    filePointer = 0;

    if (s3ObjectKeys.size() > ++fileIndex) {
      return s3ObjectKeys.get(fileIndex);
    } else {
      return null;
    }
  }
}
