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

// Containerization fix (blocker-5/cz-java-0064): Replaced JVM-local singleton state storage
// with CDI @ApplicationScoped bean. State is externalized to Azure Cache for Redis;
// connection strings are injected via environment variable REDIS_CONNECTION_STRING
// (Azure Key Vault CSI driver on AKS).
@ApplicationScoped
public class JpaCargoRepository implements CargoRepository, Serializable {

  private static final long serialVersionUID = 1L;

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
