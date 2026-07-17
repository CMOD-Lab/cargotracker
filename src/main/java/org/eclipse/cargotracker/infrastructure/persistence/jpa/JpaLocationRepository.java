package org.eclipse.cargotracker.infrastructure.persistence.jpa;

import java.io.Serializable;
import java.util.List;
// Containerization (blocker-7 / cz-java-0064): Singleton state storage identified.
// Migrate JVM singleton state to Google Cloud Memorystore (Redis) on GKE Autopilot.
// Inject Redis connection details via environment variables:
//   REDIS_HOST = System.getenv("REDIS_HOST")
//   REDIS_PORT = System.getenv("REDIS_PORT")
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.LocationRepository;
import org.eclipse.cargotracker.domain.model.location.UnLocode;

@ApplicationScoped
public class JpaLocationRepository implements LocationRepository, Serializable {

  private static final long serialVersionUID = 1L;

  @PersistenceContext private EntityManager entityManager;

  @Override
  public Location find(UnLocode unLocode) {
    return entityManager
        .createNamedQuery("Location.findByUnLocode", Location.class)
        .setParameter("unLocode", unLocode)
        .getSingleResult();
  }

  @Override
  public List<Location> findAll() {
    return entityManager.createNamedQuery("Location.findAll", Location.class).getResultList();
  }
}
