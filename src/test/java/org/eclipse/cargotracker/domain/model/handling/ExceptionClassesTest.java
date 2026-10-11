package org.eclipse.cargotracker.domain.model.handling;

import org.eclipse.cargotracker.domain.model.cargo.TrackingId;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Exception Classes Tests")
class ExceptionClassesTest {

    @Test
    @DisplayName("CannotCreateHandlingEventException with cause creates exception")
    void cannotCreateHandlingEventException_withCause_createsException() {
        Exception cause = new RuntimeException("test cause");
        CannotCreateHandlingEventException ex = new CannotCreateHandlingEventException(cause);
        assertNotNull(ex);
        assertEquals(cause, ex.getCause());
    }

    @Test
    @DisplayName("CannotCreateHandlingEventException default constructor creates exception")
    void cannotCreateHandlingEventException_defaultConstructor_createsException() {
        CannotCreateHandlingEventException ex = new CannotCreateHandlingEventException();
        assertNotNull(ex);
    }

    @Test
    @DisplayName("UnknownCargoException has correct message")
    void unknownCargoException_hasCorrectMessage() {
        TrackingId trackingId = new TrackingId("TEST001");
        UnknownCargoException ex = new UnknownCargoException(trackingId);
        assertNotNull(ex);
        assertTrue(ex.getMessage().contains("TEST001"));
    }

    @Test
    @DisplayName("UnknownLocationException has correct message")
    void unknownLocationException_hasCorrectMessage() {
        UnLocode unlocode = new UnLocode("SESTO");
        UnknownLocationException ex = new UnknownLocationException(unlocode);
        assertNotNull(ex);
        assertTrue(ex.getMessage().contains("SESTO"));
    }

    @Test
    @DisplayName("UnknownVoyageException has correct message")
    void unknownVoyageException_hasCorrectMessage() {
        VoyageNumber voyageNumber = new VoyageNumber("V001");
        UnknownVoyageException ex = new UnknownVoyageException(voyageNumber);
        assertNotNull(ex);
        assertTrue(ex.getMessage().contains("V001"));
    }

    @Test
    @DisplayName("UnknownCargoException is subclass of CannotCreateHandlingEventException")
    void unknownCargoException_isSubclassOfCannotCreate() {
        TrackingId trackingId = new TrackingId("TEST001");
        UnknownCargoException ex = new UnknownCargoException(trackingId);
        assertInstanceOf(CannotCreateHandlingEventException.class, ex);
    }

    @Test
    @DisplayName("UnknownLocationException is subclass of CannotCreateHandlingEventException")
    void unknownLocationException_isSubclassOfCannotCreate() {
        UnLocode unlocode = new UnLocode("SESTO");
        UnknownLocationException ex = new UnknownLocationException(unlocode);
        assertInstanceOf(CannotCreateHandlingEventException.class, ex);
    }

    @Test
    @DisplayName("UnknownVoyageException is subclass of CannotCreateHandlingEventException")
    void unknownVoyageException_isSubclassOfCannotCreate() {
        VoyageNumber voyageNumber = new VoyageNumber("V001");
        UnknownVoyageException ex = new UnknownVoyageException(voyageNumber);
        assertInstanceOf(CannotCreateHandlingEventException.class, ex);
    }
}
