package org.eclipse.cargotracker.domain.model.cargo;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("TransportStatus Tests")
class TransportStatusTest {

    @Test
    @DisplayName("NOT_RECEIVED sameValueAs NOT_RECEIVED returns true")
    void notReceived_sameValueAs_notReceived_returnsTrue() {
        assertTrue(TransportStatus.NOT_RECEIVED.sameValueAs(TransportStatus.NOT_RECEIVED));
    }

    @Test
    @DisplayName("IN_PORT sameValueAs IN_PORT returns true")
    void inPort_sameValueAs_inPort_returnsTrue() {
        assertTrue(TransportStatus.IN_PORT.sameValueAs(TransportStatus.IN_PORT));
    }

    @Test
    @DisplayName("ONBOARD_CARRIER sameValueAs ONBOARD_CARRIER returns true")
    void onboardCarrier_sameValueAs_onboardCarrier_returnsTrue() {
        assertTrue(TransportStatus.ONBOARD_CARRIER.sameValueAs(TransportStatus.ONBOARD_CARRIER));
    }

    @Test
    @DisplayName("CLAIMED sameValueAs CLAIMED returns true")
    void claimed_sameValueAs_claimed_returnsTrue() {
        assertTrue(TransportStatus.CLAIMED.sameValueAs(TransportStatus.CLAIMED));
    }

    @Test
    @DisplayName("UNKNOWN sameValueAs UNKNOWN returns true")
    void unknown_sameValueAs_unknown_returnsTrue() {
        assertTrue(TransportStatus.UNKNOWN.sameValueAs(TransportStatus.UNKNOWN));
    }

    @Test
    @DisplayName("NOT_RECEIVED sameValueAs IN_PORT returns false")
    void notReceived_sameValueAs_inPort_returnsFalse() {
        assertFalse(TransportStatus.NOT_RECEIVED.sameValueAs(TransportStatus.IN_PORT));
    }

    @Test
    @DisplayName("All enum values are accessible")
    void allEnumValues_areAccessible() {
        TransportStatus[] values = TransportStatus.values();
        assertEquals(5, values.length);
    }

    @Test
    @DisplayName("valueOf returns correct enum")
    void valueOf_returnsCorrectEnum() {
        assertEquals(TransportStatus.NOT_RECEIVED, TransportStatus.valueOf("NOT_RECEIVED"));
        assertEquals(TransportStatus.IN_PORT, TransportStatus.valueOf("IN_PORT"));
        assertEquals(TransportStatus.ONBOARD_CARRIER, TransportStatus.valueOf("ONBOARD_CARRIER"));
        assertEquals(TransportStatus.CLAIMED, TransportStatus.valueOf("CLAIMED"));
        assertEquals(TransportStatus.UNKNOWN, TransportStatus.valueOf("UNKNOWN"));
    }
}
