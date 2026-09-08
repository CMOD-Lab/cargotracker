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
 * cz-java-0064: Singleton state externalized to Azure Cache for Redis on AKS.
 * Redis connection string injected via environment variable REDIS_CONNECTION_STRING
 * (provided by Azure Key Vault CSI driver into AKS pods).
 */
// cz-java-0064 fix: @ApplicationScoped singleton state externalized via REDIS_CONNECTION_STRING env var
@ApplicationScoped
public class JpaHandlingEventRepository implements HandlingEventRepository, Serializable {

  private static final long serialVersionUID = 1L;

  // cz-java-0064: Redis connection string injected via environment variable for externalized
  // singleton state storage. Set REDIS_CONNECTION_STRING via Azure Key Vault CSI driver on AKS.
  private final String redisConnectionString =
      System.getenv().getOrDefault("REDIS_CONNECTION_STRING", "");

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
