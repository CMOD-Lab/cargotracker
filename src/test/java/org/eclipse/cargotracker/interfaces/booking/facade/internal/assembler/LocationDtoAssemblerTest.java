package org.eclipse.cargotracker.interfaces.booking.facade.internal.assembler;

import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("LocationDtoAssembler Tests")
class LocationDtoAssemblerTest {

    private LocationDtoAssembler assembler;
    private Location stockholm;
    private Location hamburg;
    private Location newYork;

    @BeforeEach
    void setUp() {
        assembler = new LocationDtoAssembler();
        stockholm = new Location(new UnLocode("SESTO"), "Stockholm");
        hamburg = new Location(new UnLocode("DEHAM"), "Hamburg");
        newYork = new Location(new UnLocode("USNYC"), "New York");
    }

    @Test
    @DisplayName("toDto converts Location to DTO")
    void toDto_validLocation_convertsToDto() {
        org.eclipse.cargotracker.interfaces.booking.facade.dto.Location dto =
                assembler.toDto(stockholm);
        assertNotNull(dto);
        assertEquals("SESTO", dto.getUnLocode());
        assertEquals("Stockholm", dto.getName());
    }

    @Test
    @DisplayName("toDto converts Hamburg location to DTO")
    void toDto_hamburgLocation_convertsToDto() {
        org.eclipse.cargotracker.interfaces.booking.facade.dto.Location dto =
                assembler.toDto(hamburg);
        assertNotNull(dto);
        assertEquals("DEHAM", dto.getUnLocode());
        assertEquals("Hamburg", dto.getName());
    }

    @Test
    @DisplayName("toDtoList converts list of locations to sorted DTOs")
    void toDtoList_validLocations_convertsToDtoList() {
        List<Location> locations = Arrays.asList(newYork, stockholm, hamburg);
        List<org.eclipse.cargotracker.interfaces.booking.facade.dto.Location> dtos =
                assembler.toDtoList(locations);

        assertNotNull(dtos);
        assertEquals(3, dtos.size());
    }

    @Test
    @DisplayName("toDtoList returns sorted list by unLocode")
    void toDtoList_validLocations_returnsSortedByUnLocode() {
        List<Location> locations = Arrays.asList(newYork, stockholm, hamburg);
        List<org.eclipse.cargotracker.interfaces.booking.facade.dto.Location> dtos =
                assembler.toDtoList(locations);

        // Should be sorted: DEHAM, SESTO, USNYC
        assertEquals("DEHAM", dtos.get(0).getUnLocode());
        assertEquals("SESTO", dtos.get(1).getUnLocode());
        assertEquals("USNYC", dtos.get(2).getUnLocode());
    }

    @Test
    @DisplayName("toDtoList with empty list returns empty list")
    void toDtoList_emptyList_returnsEmptyList() {
        List<org.eclipse.cargotracker.interfaces.booking.facade.dto.Location> dtos =
                assembler.toDtoList(Arrays.asList());
        assertNotNull(dtos);
        assertTrue(dtos.isEmpty());
    }
}
