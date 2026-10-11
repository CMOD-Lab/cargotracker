package org.eclipse.pathfinder.api;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("TransitPath Tests")
class TransitPathTest {

    private TransitEdge edge1;
    private TransitEdge edge2;
    private TransitPath transitPath;

    @BeforeEach
    void setUp() {
        edge1 = new TransitEdge("V001", "SESTO", "DEHAM",
                LocalDateTime.of(2024, 1, 1, 10, 0),
                LocalDateTime.of(2024, 1, 3, 10, 0));
        edge2 = new TransitEdge("V002", "DEHAM", "USNYC",
                LocalDateTime.of(2024, 1, 4, 10, 0),
                LocalDateTime.of(2024, 1, 10, 10, 0));
        transitPath = new TransitPath(Arrays.asList(edge1, edge2));
    }

    @Test
    @DisplayName("Constructor creates TransitPath with edges")
    void constructor_withEdges_createsTransitPath() {
        assertNotNull(transitPath);
        assertEquals(2, transitPath.getTransitEdges().size());
    }

    @Test
    @DisplayName("Default constructor creates empty TransitPath")
    void defaultConstructor_createsEmptyTransitPath() {
        TransitPath path = new TransitPath();
        assertNotNull(path);
        assertNotNull(path.getTransitEdges());
        assertTrue(path.getTransitEdges().isEmpty());
    }

    @Test
    @DisplayName("getTransitEdges returns edges")
    void getTransitEdges_returnsEdges() {
        List<TransitEdge> edges = transitPath.getTransitEdges();
        assertNotNull(edges);
        assertEquals(2, edges.size());
    }

    @Test
    @DisplayName("setTransitEdges updates edges")
    void setTransitEdges_updatesEdges() {
        List<TransitEdge> newEdges = Arrays.asList(edge1);
        transitPath.setTransitEdges(newEdges);
        assertEquals(1, transitPath.getTransitEdges().size());
    }

    @Test
    @DisplayName("toString returns non-null string")
    void toString_returnsNonNullString() {
        String result = transitPath.toString();
        assertNotNull(result);
        assertTrue(result.contains("TransitPath"));
    }

    @Test
    @DisplayName("Constructor with empty list creates TransitPath")
    void constructor_withEmptyList_createsTransitPath() {
        TransitPath emptyPath = new TransitPath(Collections.emptyList());
        assertNotNull(emptyPath);
        assertTrue(emptyPath.getTransitEdges().isEmpty());
    }
}
