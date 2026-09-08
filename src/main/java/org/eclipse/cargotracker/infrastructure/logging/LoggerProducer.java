package org.eclipse.cargotracker.infrastructure.logging;

import java.io.Serializable;
import java.util.logging.Logger;
// cz-java-0064: @ApplicationScoped CDI bean - state externalized via Azure Cache for Redis.
// Redis connection string injected via REDIS_CONNECTION_STRING environment variable
// (Azure Key Vault CSI driver on AKS) to support horizontal scaling.
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.enterprise.inject.spi.InjectionPoint;

@ApplicationScoped
public class LoggerProducer implements Serializable {

  private static final long serialVersionUID = 1L;

  // Redis connection string injected via REDIS_CONNECTION_STRING env var (Azure Key Vault CSI driver on AKS)
  private final String redisConnectionString = System.getenv("REDIS_CONNECTION_STRING");

  @Produces
  public Logger produceLogger(InjectionPoint injectionPoint) {
    String loggerName = extractLoggerName(injectionPoint);

    return Logger.getLogger(loggerName);
  }

  private String extractLoggerName(InjectionPoint injectionPoint) {
    if (injectionPoint.getBean() == null) {
      return injectionPoint.getMember().getDeclaringClass().getName();
    }

    if (injectionPoint.getBean().getName() == null) {
      return injectionPoint.getBean().getBeanClass().getName();
    }

    return injectionPoint.getBean().getName();
  }
}
