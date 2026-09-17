package org.eclipse.cargotracker.interfaces;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;
import jakarta.inject.Inject;
import org.eclipse.cargotracker.infrastructure.cache.RedisStateManager;

/**
 * Jakarta Faces configuration.
 *
 * <p>Uses CDI {@code @ApplicationScoped} (stateless configuration bean). Any shared state is
 * externalized to Amazon ElastiCache (Redis) via {@link RedisStateManager} to ensure
 * consistency across all EKS pod replicas (cz-java-0064).
 */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {

  /** Redis-based state manager – externalizes singleton state to ElastiCache. */
  @Inject private RedisStateManager redisStateManager;
}
