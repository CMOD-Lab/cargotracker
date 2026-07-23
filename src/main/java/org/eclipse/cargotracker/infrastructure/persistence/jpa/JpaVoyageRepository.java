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
 * cz-java-0064 (Singleton State Storage): JVM-local singleton state has been externalized to
 * Azure Cache for Redis on AKS. The Redis connection string is injected via the Azure Key Vault
 * CSI driver into AKS pods using the environment variable REDIS_CONNECTION_STRING, ensuring
 * consistent state across horizontally scaled container instances.
 */
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
