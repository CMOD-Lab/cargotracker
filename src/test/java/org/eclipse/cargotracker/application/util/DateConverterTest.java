package org.eclipse.cargotracker.application.util;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("DateConverter Tests")
class DateConverterTest {

    @Test
    @DisplayName("toString converts LocalDate to string")
    void toString_localDate_convertsToString() {
        LocalDate date = LocalDate.of(2024, 1, 15);
        String result = DateConverter.toString(date);
        assertNotNull(result);
        assertEquals("1/15/2024", result);
    }

    @Test
    @DisplayName("toString converts LocalDateTime to string")
    void toString_localDateTime_convertsToString() {
        LocalDateTime dateTime = LocalDateTime.of(2024, 1, 15, 10, 30);
        String result = DateConverter.toString(dateTime);
        assertNotNull(result);
        assertTrue(result.contains("1/15/2024"));
    }

    @Test
    @DisplayName("toDate converts string to LocalDate")
    void toDate_validString_convertsToLocalDate() {
        String dateStr = "1/15/2024";
        LocalDate result = DateConverter.toDate(dateStr);
        assertNotNull(result);
        assertEquals(LocalDate.of(2024, 1, 15), result);
    }

    @Test
    @DisplayName("toDateTime converts string to LocalDateTime")
    void toDateTime_validString_convertsToLocalDateTime() {
        String dateTimeStr = "1/15/2024 10:30 AM";
        LocalDateTime result = DateConverter.toDateTime(dateTimeStr);
        assertNotNull(result);
        assertEquals(LocalDateTime.of(2024, 1, 15, 10, 30), result);
    }

    @Test
    @DisplayName("DATE_FORMAT constant is correct")
    void dateFormatConstant_isCorrect() {
        assertEquals("M/d/yyyy", DateConverter.DATE_FORMAT);
    }

    @Test
    @DisplayName("DATE_TIME_FORMAT constant is correct")
    void dateTimeFormatConstant_isCorrect() {
        assertEquals("M/d/yyyy h:m a", DateConverter.DATE_TIME_FORMAT);
    }

    @Test
    @DisplayName("toString and toDate are inverse operations")
    void toStringAndToDate_areInverseOperations() {
        LocalDate original = LocalDate.of(2024, 6, 15);
        String str = DateConverter.toString(original);
        LocalDate result = DateConverter.toDate(str);
        assertEquals(original, result);
    }

    @Test
    @DisplayName("toString and toDateTime are inverse operations")
    void toStringAndToDateTime_areInverseOperations() {
        LocalDateTime original = LocalDateTime.of(2024, 6, 15, 14, 30);
        String str = DateConverter.toString(original);
        LocalDateTime result = DateConverter.toDateTime(str);
        assertEquals(original, result);
    }

    @Test
    @DisplayName("toString handles single digit month and day")
    void toString_singleDigitMonthAndDay_formatsCorrectly() {
        LocalDate date = LocalDate.of(2024, 1, 5);
        String result = DateConverter.toString(date);
        assertEquals("1/5/2024", result);
    }

    @Test
    @DisplayName("toString handles double digit month and day")
    void toString_doubleDigitMonthAndDay_formatsCorrectly() {
        LocalDate date = LocalDate.of(2024, 12, 25);
        String result = DateConverter.toString(date);
        assertEquals("12/25/2024", result);
    }
}
