package org.eclipse.cargotracker.domain.model.cargo;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("RoutingStatus Tests")
class RoutingStatusTest {

    @Test
    @DisplayName("NOT_ROUTED sameValueAs NOT_ROUTED returns true")
    void notRouted_sameValueAs_notRouted_returnsTrue() {
        assertTrue(RoutingStatus.NOT_ROUTED.sameValueAs(RoutingStatus.NOT_ROUTED));
    }

    @Test
    @DisplayName("ROUTED sameValueAs ROUTED returns true")
    void routed_sameValueAs_routed_returnsTrue() {
        assertTrue(RoutingStatus.ROUTED.sameValueAs(RoutingStatus.ROUTED));
    }

    @Test
    @DisplayName("MISROUTED sameValueAs MISROUTED returns true")
    void misrouted_sameValueAs_misrouted_returnsTrue() {
        assertTrue(RoutingStatus.MISROUTED.sameValueAs(RoutingStatus.MISROUTED));
    }

    @Test
    @DisplayName("NOT_ROUTED sameValueAs ROUTED returns false")
    void notRouted_sameValueAs_routed_returnsFalse() {
        assertFalse(RoutingStatus.NOT_ROUTED.sameValueAs(RoutingStatus.ROUTED));
    }

    @Test
    @DisplayName("ROUTED sameValueAs MISROUTED returns false")
    void routed_sameValueAs_misrouted_returnsFalse() {
        assertFalse(RoutingStatus.ROUTED.sameValueAs(RoutingStatus.MISROUTED));
    }

    @Test
    @DisplayName("All enum values are accessible")
    void allEnumValues_areAccessible() {
        RoutingStatus[] values = RoutingStatus.values();
        assertEquals(3, values.length);
    }

    @Test
    @DisplayName("valueOf returns correct enum")
    void valueOf_returnsCorrectEnum() {
        assertEquals(RoutingStatus.NOT_ROUTED, RoutingStatus.valueOf("NOT_ROUTED"));
        assertEquals(RoutingStatus.ROUTED, RoutingStatus.valueOf("ROUTED"));
        assertEquals(RoutingStatus.MISROUTED, RoutingStatus.valueOf("MISROUTED"));
    }
}
