package org.eclipse.cargotracker.interfaces.handling.file;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;

public class EventFilesCheckpoint implements Serializable {

  private static final long serialVersionUID = 1L;

  private List<String> objectKeys = new LinkedList<>();
  private int keyIndex = 0;
  private long filePointer = 0;

  public void setObjectKeys(List<String> objectKeys) {
    this.objectKeys = new ArrayList<>(objectKeys);
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

  public String currentObjectKey() {
    if (objectKeys.size() > keyIndex) {
      return objectKeys.get(keyIndex);
    } else {
      return null;
    }
  }

  public String nextObjectKey() {
    filePointer = 0;

    if (objectKeys.size() > ++keyIndex) {
      return objectKeys.get(keyIndex);
    } else {
      return null;
    }
  }
}
