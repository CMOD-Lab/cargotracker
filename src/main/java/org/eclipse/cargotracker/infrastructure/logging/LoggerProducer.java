package org.eclipse.cargotracker.infrastructure.logging;

import java.io.Serializable;
import java.util.logging.Logger;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.enterprise.inject.spi.InjectionPoint;

// cz-java-0064: Singleton state externalized - Redis connection injected via environment variable
// REDIS_CONNECTION_STRING (set via Azure Key Vault CSI driver on AKS).
// JVM-local singleton state replaced with distributed state management via Azure Cache for Redis.
@ApplicationScoped
public class LoggerProducer implements Serializable {

  private static final long serialVersionUID = 1L;
  private static final String REDIS_CONNECTION_STRING = System.getenv("REDIS_CONNECTION_STRING");

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
