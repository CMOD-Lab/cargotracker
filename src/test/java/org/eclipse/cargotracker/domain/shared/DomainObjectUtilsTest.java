package org.eclipse.cargotracker.domain.shared;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("DomainObjectUtils Tests")
class DomainObjectUtilsTest {

    @Test
    @DisplayName("nullSafe returns actual value when not null")
    void nullSafe_withNonNullActual_returnsActual() {
        String actual = "actual";
        String safe = "safe";
        assertEquals("actual", DomainObjectUtils.nullSafe(actual, safe));
    }

    @Test
    @DisplayName("nullSafe returns safe value when actual is null")
    void nullSafe_withNullActual_returnsSafe() {
        String actual = null;
        String safe = "safe";
        assertEquals("safe", DomainObjectUtils.nullSafe(actual, safe));
    }

    @Test
    @DisplayName("nullSafe works with Integer type")
    void nullSafe_withIntegerType_works() {
        Integer actual = 42;
        Integer safe = 0;
        assertEquals(42, DomainObjectUtils.nullSafe(actual, safe));
    }

    @Test
    @DisplayName("nullSafe returns safe when actual Integer is null")
    void nullSafe_withNullInteger_returnsSafe() {
        Integer actual = null;
        Integer safe = 0;
        assertEquals(0, DomainObjectUtils.nullSafe(actual, safe));
    }

    @Test
    @DisplayName("nullSafe works with Object type")
    void nullSafe_withObjectType_works() {
        Object actual = new Object();
        Object safe = new Object();
        assertSame(actual, DomainObjectUtils.nullSafe(actual, safe));
    }
}
