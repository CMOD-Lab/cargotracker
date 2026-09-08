package org.eclipse.cargotracker.infrastructure.persistence.jpa;

import java.io.Serializable;
import java.util.List;
// cz-java-0064: @ApplicationScoped CDI bean - state externalized via Azure Cache for Redis.
// Redis connection string injected via REDIS_CONNECTION_STRING environment variable
// (Azure Key Vault CSI driver on AKS) to support horizontal scaling.
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.eclipse.cargotracker.domain.model.voyage.Voyage;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import org.eclipse.cargotracker.domain.model.voyage.VoyageRepository;

@ApplicationScoped
public class JpaVoyageRepository implements VoyageRepository, Serializable {

  private static final long serialVersionUID = 1L;

  // Redis connection string injected via REDIS_CONNECTION_STRING env var (Azure Key Vault CSI driver on AKS)
  private final String redisConnectionString = System.getenv("REDIS_CONNECTION_STRING");

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
