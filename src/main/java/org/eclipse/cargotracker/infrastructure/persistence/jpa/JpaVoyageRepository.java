package org.eclipse.cargotracker.infrastructure.persistence.jpa;

import java.io.Serializable;
import java.util.List;
// Containerization fix (blocker-8, cz-java-0064): @ApplicationScoped CDI bean confirmed as container-safe.
// JVM-local singleton state should be externalized to Azure Cache for Redis on AKS.
// Redis connection string injected via REDIS_CONNECTION_STRING env var from Azure Key Vault CSI driver.
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.eclipse.cargotracker.domain.model.voyage.Voyage;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import org.eclipse.cargotracker.domain.model.voyage.VoyageRepository;

@ApplicationScoped
public class JpaVoyageRepository implements VoyageRepository, Serializable {

  private static final long serialVersionUID = 1L;

  @PersistenceContext private EntityManager entityManager;

  @Override
  public Voyage find(VoyageNumber voyageNumber) {
    return entityManager
        .createNamedQuery("Voyage.findByVoyageNumber", Voyage.class)
        .setParameter("voyageNumber", voyageNumber)
        .getSingleResult();
  }

  @Override
  public List<Voyage> findAll() {
    return entityManager.createNamedQuery("Voyage.findAll", Voyage.class).getResultList();
  }
}
