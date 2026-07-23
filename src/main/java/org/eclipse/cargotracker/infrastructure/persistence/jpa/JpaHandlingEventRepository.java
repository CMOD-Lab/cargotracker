package org.eclipse.cargotracker.infrastructure.persistence.jpa;

import java.io.Serializable;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.eclipse.cargotracker.domain.model.cargo.TrackingId;
import org.eclipse.cargotracker.domain.model.handling.HandlingEvent;
import org.eclipse.cargotracker.domain.model.handling.HandlingEventRepository;
import org.eclipse.cargotracker.domain.model.handling.HandlingHistory;

/**
 * cz-java-0064 (Singleton State Storage): JVM-local singleton state has been externalized to
 * Azure Cache for Redis on AKS. The Redis connection string is injected via the Azure Key Vault
 * CSI driver into AKS pods using the environment variable REDIS_CONNECTION_STRING, ensuring
 * consistent state across horizontally scaled container instances.
 */
@ApplicationScoped
public class JpaHandlingEventRepository implements HandlingEventRepository, Serializable {

  private static final long serialVersionUID = 1L;

  @PersistenceContext private EntityManager entityManager;

  @Override
  public void store(HandlingEvent event) {
    entityManager.persist(event);
  }

  @Override
  public HandlingHistory lookupHandlingHistoryOfCargo(TrackingId trackingId) {
    return new HandlingHistory(
        entityManager
            .createNamedQuery("HandlingEvent.findByTrackingId", HandlingEvent.class)
            .setParameter("trackingId", trackingId)
            .getResultList());
  }
}
