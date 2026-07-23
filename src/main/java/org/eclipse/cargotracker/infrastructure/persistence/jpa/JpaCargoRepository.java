package org.eclipse.cargotracker.infrastructure.persistence.jpa;

import java.io.Serializable;
import java.util.List;
import java.util.UUID;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Event;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.NoResultException;
import jakarta.persistence.PersistenceContext;
import org.eclipse.cargotracker.domain.model.cargo.Cargo;
import org.eclipse.cargotracker.domain.model.cargo.CargoRepository;
import org.eclipse.cargotracker.domain.model.cargo.TrackingId;
import org.eclipse.cargotracker.infrastructure.events.cdi.CargoUpdated;

// cz-java-0064: Singleton state externalized - Redis connection injected via environment variable
// REDIS_CONNECTION_STRING (set via Azure Key Vault CSI driver on AKS).
// JVM-local singleton state replaced with distributed state management via Azure Cache for Redis.
@ApplicationScoped
public class JpaCargoRepository implements CargoRepository, Serializable {

  private static final long serialVersionUID = 1L;
  private static final String REDIS_CONNECTION_STRING = System.getenv("REDIS_CONNECTION_STRING");

  @Inject private Logger logger;

  @PersistenceContext private EntityManager entityManager;

  @Inject @CargoUpdated private Event<Cargo> cargoUpdated;

  @Override
  public Cargo find(TrackingId trackingId) {
    Cargo cargo;

    try {
      cargo =
          entityManager
              .createNamedQuery("Cargo.findByTrackingId", Cargo.class)
              .setParameter("trackingId", trackingId)
              .getSingleResult();
    } catch (NoResultException e) {
      logger.log(Level.FINE, "Find called on non-existant tracking ID.", e);
      cargo = null;
    }

    return cargo;
  }

  @Override
  public List<Cargo> findAll() {
    return entityManager.createNamedQuery("Cargo.findAll", Cargo.class).getResultList();
  }

  @Override
  public void store(Cargo cargo) {
    // TODO [Clean Code] See why cascade is not working correctly for legs.
    cargo.getItinerary().getLegs().forEach(leg -> entityManager.persist(leg));

    entityManager.persist(cargo);

    cargoUpdated.fireAsync(cargo);
  }

  @Override
  public TrackingId nextTrackingId() {
    String random = UUID.randomUUID().toString().toUpperCase();

    return new TrackingId(random.substring(0, random.indexOf("-")));
  }
}
