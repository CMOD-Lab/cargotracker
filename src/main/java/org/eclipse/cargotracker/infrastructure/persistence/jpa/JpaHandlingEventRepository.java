package org.eclipse.cargotracker.infrastructure.persistence.jpa;

import java.io.Serializable;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.eclipse.cargotracker.domain.model.cargo.TrackingId;
import org.eclipse.cargotracker.domain.model.handling.HandlingEvent;
import org.eclipse.cargotracker.domain.model.handling.HandlingEventRepository;
import org.eclipse.cargotracker.domain.model.handling.HandlingHistory;
import org.eclipse.cargotracker.infrastructure.cache.RedisStateManager;

/**
 * JPA-based implementation of {@link HandlingEventRepository}.
 *
 * <p>Uses CDI {@code @ApplicationScoped} (stateless repository bean). Any shared state is
 * externalized to Amazon ElastiCache (Redis) via {@link RedisStateManager} to ensure
 * consistency across all EKS pod replicas (cz-java-0064).
 */
@ApplicationScoped
public class JpaHandlingEventRepository implements HandlingEventRepository, Serializable {

  private static final long serialVersionUID = 1L;

  @PersistenceContext private EntityManager entityManager;

  /** Redis-based state manager – externalizes singleton state to ElastiCache. */
  @Inject private RedisStateManager redisStateManager;

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
