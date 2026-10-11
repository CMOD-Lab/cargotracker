package org.eclipse.cargotracker.interfaces.booking.facade.dto;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("RouteCandidate DTO Tests")
class RouteCandidateTest {

    private List<Leg> legs;
    private RouteCandidate routeCandidate;

    @BeforeEach
    void setUp() {
        Location from = new Location("SESTO", "Stockholm");
        Location to = new Location("DEHAM", "Hamburg");
        Leg leg = new Leg("V001", from, to,
                LocalDateTime.of(2024, 1, 1, 10, 0),
                LocalDateTime.of(2024, 1, 3, 10, 0));
        legs = Arrays.asList(leg);
        routeCandidate = new RouteCandidate(legs);
    }

    @Test
    @DisplayName("Constructor creates RouteCandidate with legs")
    void constructor_withLegs_createsRouteCandidate() {
        assertNotNull(routeCandidate);
        assertEquals(1, routeCandidate.getLegs().size());
    }

    @Test
    @DisplayName("getLegs returns unmodifiable list")
    void getLegs_returnsUnmodifiableList() {
        List<Leg> result = routeCandidate.getLegs();
        assertNotNull(result);
        assertEquals(1, result.size());
        assertThrows(UnsupportedOperationException.class, () -> result.add(legs.get(0)));
    }

    @Test
    @DisplayName("toString returns non-null string")
    void toString_returnsNonNullString() {
        String result = routeCandidate.toString();
        assertNotNull(result);
        assertTrue(result.contains("RouteCandidate"));
    }

    @Test
    @DisplayName("Constructor with empty legs creates RouteCandidate")
    void constructor_withEmptyLegs_createsRouteCandidate() {
        RouteCandidate emptyCandidate = new RouteCandidate(Collections.emptyList());
        assertNotNull(emptyCandidate);
        assertTrue(emptyCandidate.getLegs().isEmpty());
    }
}
