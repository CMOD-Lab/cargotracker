package org.eclipse.cargotracker.application.util;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;

/**
 * Date/time converter utility standardized on UTC for cloud-native deployments.
 * Eliminates server-local timezone dependencies to ensure consistent behavior
 * across distributed cloud instances.
 */
// TODO [Clean Code] Make this a CDI singleton?
public class DateConverter {
  public static final String DATE_FORMAT = "M/d/yyyy";
  public static final String DATE_TIME_FORMAT = "M/d/yyyy h:m a";

  // Standardized on UTC to eliminate server-local timezone dependencies
  private static final DateTimeFormatter DATE_FORMATTER =
      DateTimeFormatter.ofPattern(DATE_FORMAT).withZone(ZoneOffset.UTC);

  private static final DateTimeFormatter DATE_TIME_FORMATTER =
      DateTimeFormatter.ofPattern(DATE_TIME_FORMAT).withZone(ZoneOffset.UTC);

  private DateConverter() {}

  public static LocalDate toDate(String date) {
    return LocalDate.parse(date, DATE_FORMATTER);
  }

  public static LocalDateTime toDateTime(String datetime) {
    return LocalDateTime.parse(datetime, DATE_TIME_FORMATTER);
  }

  public static String toString(LocalDateTime dateTime) {
    return dateTime.format(DATE_TIME_FORMATTER);
  }

  public static String toString(LocalDate date) {
    return date.format(DATE_FORMATTER);
  }
}
