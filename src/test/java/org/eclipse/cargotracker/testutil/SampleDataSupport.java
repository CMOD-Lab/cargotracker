package org.eclipse.cargotracker.testutil;

import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.eclipse.cargotracker.domain.model.voyage.Voyage;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;

import java.time.LocalDateTime;

/**
 * Test utility class providing helper methods for creating test domain objects.
 */
public class SampleDataSupport {

    public static final Location STOCKHOLM = new Location(new UnLocode("SESTO"), "Stockholm");
    public static final Location HAMBURG = new Location(new UnLocode("DEHAM"), "Hamburg");
    public static final Location NEW_YORK = new Location(new UnLocode("USNYC"), "New York");
    public static final Location DALLAS = new Location(new UnLocode("USDAL"), "Dallas");
    public static final Location HELSINKI = new Location(new UnLocode("FIHEL"), "Helsinki");

    /**
     * Creates a voyage using the Builder pattern (which is public).
     */
    public static Voyage createVoyage(String voyageNumber, Location from, Location to,
                                       LocalDateTime departureTime, LocalDateTime arrivalTime) {
        return new Voyage.Builder(new VoyageNumber(voyageNumber), from)
                .addMovement(to, departureTime, arrivalTime)
                .build();
    }

    /**
     * Creates a simple voyage from one location to another.
     */
    public static Voyage createSimpleVoyage(String voyageNumber, Location from, Location to) {
        LocalDateTime dep = LocalDateTime.of(2024, 1, 1, 10, 0);
        LocalDateTime arr = LocalDateTime.of(2024, 1, 3, 10, 0);
        return createVoyage(voyageNumber, from, to, dep, arr);
    }
}
