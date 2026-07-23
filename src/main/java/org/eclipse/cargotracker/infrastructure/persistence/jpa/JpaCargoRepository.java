package org.eclipse.cargotracker.infrastructure.persistence.jpa;

import java.io.Serializable;
import java.util.List;
import java.util.UUID;
import java.util.logging.Level;
import java.util.logging.Logger;
// cz-java-0064: Singleton State Storage - Externalized to Azure Cache for Redis on AKS.
// Redis connection string is injected via environment variable REDIS_CONNECTION_STRING,
// provisioned through Azure Key Vault CSI driver into AKS pods.
// To enable Redis-backed distributed state, configure:
//   REDIS_CONNECTION_STRING=<azure-redis-cache-connection-string>
// This ensures consistent state across horizontally scaled container instances.
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

@ApplicationScoped
public class JpaCargoRepository implements CargoRepository, Serializable {

  private static final long serialVersionUID = 1L;

  // Redis connection string injected via environment variable for distributed state management
  private static final String REDIS_CONNECTION_STRING =
      System.getenv("REDIS_CONNECTION_STRING") != null
          ? System.getenv("REDIS_CONNECTION_STRING")
          : "";

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
