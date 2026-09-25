package org.eclipse.cargotracker.interfaces.handling.file;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.batch.api.listener.JobListener;
import jakarta.enterprise.context.Dependent;
import jakarta.inject.Inject;
import jakarta.inject.Named;

/**
 * Job listener for the file processor batch job.
 * Uses UTC timestamps to ensure consistent behavior across distributed cloud instances.
 */
@Dependent
@Named("FileProcessorJobListener")
public class FileProcessorJobListener implements JobListener {

  @Inject private Logger logger;

  @Override
  public void beforeJob() throws Exception {
    // Use UTC timestamp to eliminate server-local timezone dependencies
    logger.log(Level.INFO, "Handling event file processor batch job starting at {0}",
        LocalDateTime.now(ZoneOffset.UTC));
  }

  @Override
  public void afterJob() throws Exception {
    // Use UTC timestamp to eliminate server-local timezone dependencies
    logger.log(Level.INFO, "Handling event file processor batch job completed at {0}",
        LocalDateTime.now(ZoneOffset.UTC));
  }
}
