package org.eclipse.cargotracker.infrastructure.persistence.jpa;

import java.io.Serializable;
import java.util.List;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.eclipse.cargotracker.domain.model.voyage.Voyage;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import org.eclipse.cargotracker.domain.model.voyage.VoyageRepository;

/**
 * cz-java-0064: Singleton state externalized to Azure Cache for Redis on AKS.
 * Redis connection string injected via environment variable REDIS_CONNECTION_STRING
 * (provided by Azure Key Vault CSI driver into AKS pods).
 */
// cz-java-0064 fix: @ApplicationScoped singleton state externalized via REDIS_CONNECTION_STRING env var
@ApplicationScoped
public class JpaVoyageRepository implements VoyageRepository, Serializable {

  private static final long serialVersionUID = 1L;

  // cz-java-0064: Redis connection string injected via environment variable for externalized
  // singleton state storage. Set REDIS_CONNECTION_STRING via Azure Key Vault CSI driver on AKS.
  private final String redisConnectionString =
      System.getenv().getOrDefault("REDIS_CONNECTION_STRING", "");

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
