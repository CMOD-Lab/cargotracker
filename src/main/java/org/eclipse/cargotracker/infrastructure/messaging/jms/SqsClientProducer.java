package org.eclipse.cargotracker.infrastructure.messaging.jms;

import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Inject;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sqs.SqsClient;

/**
 * CDI producer for the Amazon SQS client.
 *
 * <p>Produces an application-scoped {@link SqsClient} configured from the environment variable
 * {@code AWS_REGION} (defaults to {@code us-east-1} if not set). The AWS SDK automatically
 * resolves credentials from the default credential provider chain (IAM role, environment
 * variables, {@code ~/.aws/credentials}, etc.).
 */
@ApplicationScoped
public class SqsClientProducer {

  private static final String AWS_REGION_ENV = "AWS_REGION";
  private static final String DEFAULT_REGION = "us-east-1";

  @Inject private Logger logger;

  @Produces
  @ApplicationScoped
  public SqsClient produceSqsClient() {
    String regionStr = System.getenv(AWS_REGION_ENV);
    if (regionStr == null || regionStr.isBlank()) {
      regionStr = DEFAULT_REGION;
      logger.log(
          Level.INFO,
          "AWS_REGION environment variable not set; defaulting to {0}",
          DEFAULT_REGION);
    }
    Region region = Region.of(regionStr);
    logger.log(Level.INFO, "Creating SqsClient for region: {0}", region);
    return SqsClient.builder().region(region).build();
  }
}
