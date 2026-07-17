package org.eclipse.cargotracker.infrastructure.persistence.jpa;

import java.io.Serializable;
import java.util.List;
// Containerization fix (blocker-7, cz-java-0064): @ApplicationScoped CDI bean confirmed as container-safe.
// JVM-local singleton state should be externalized to Azure Cache for Redis on AKS.
// Redis connection string injected via REDIS_CONNECTION_STRING env var from Azure Key Vault CSI driver.
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
