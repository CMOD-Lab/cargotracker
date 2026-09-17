package org.eclipse.cargotracker.infrastructure.cache;

import java.io.Serializable;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import jakarta.enterprise.context.ApplicationScoped;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

/**
 * Redis-based state manager for externalizing singleton state to Amazon ElastiCache (Redis)
 * so all EKS pod replicas share a single consistent data store.
 *
 * <p>Connection parameters are read from environment variables:
 * <ul>
 *   <li>{@code REDIS_HOST} – ElastiCache primary endpoint (default: {@code localhost})</li>
 *   <li>{@code REDIS_PORT} – Redis port (default: {@code 6379})</li>
 *   <li>{@code REDIS_PASSWORD} – Redis AUTH password (optional)</li>
 * </ul>
 */
@ApplicationScoped
public class RedisStateManager implements Serializable {

    private static final long serialVersionUID = 1L;

    private static final Logger logger = Logger.getLogger(RedisStateManager.class.getName());

    private static final String REDIS_HOST =
            System.getenv("REDIS_HOST") != null ? System.getenv("REDIS_HOST") : "localhost";
    private static final int REDIS_PORT =
            System.getenv("REDIS_PORT") != null ? Integer.parseInt(System.getenv("REDIS_PORT")) : 6379;
    private static final String REDIS_PASSWORD = System.getenv("REDIS_PASSWORD");

    private JedisPool jedisPool;

    @PostConstruct
    public void init() {
        try {
            JedisPoolConfig poolConfig = new JedisPoolConfig();
            poolConfig.setMaxTotal(10);
            poolConfig.setMaxIdle(5);
            poolConfig.setMinIdle(1);
            poolConfig.setTestOnBorrow(true);

            if (REDIS_PASSWORD != null && !REDIS_PASSWORD.isEmpty()) {
                jedisPool = new JedisPool(poolConfig, REDIS_HOST, REDIS_PORT, 2000, REDIS_PASSWORD);
            } else {
                jedisPool = new JedisPool(poolConfig, REDIS_HOST, REDIS_PORT);
            }
            logger.log(Level.INFO, "RedisStateManager connected to ElastiCache at {0}:{1}",
                    new Object[]{REDIS_HOST, REDIS_PORT});
        } catch (Exception e) {
            logger.log(Level.SEVERE, "Failed to initialize Redis connection pool", e);
        }
    }

    @PreDestroy
    public void destroy() {
        if (jedisPool != null && !jedisPool.isClosed()) {
            jedisPool.close();
            logger.log(Level.INFO, "RedisStateManager connection pool closed.");
        }
    }

    /**
     * Sets a string value in Redis with an optional TTL (seconds). TTL <= 0 means no expiry.
     */
    public void set(String key, String value, int ttlSeconds) {
        try (Jedis jedis = jedisPool.getResource()) {
            if (ttlSeconds > 0) {
                jedis.setex(key, ttlSeconds, value);
            } else {
                jedis.set(key, value);
            }
        }
    }

    /**
     * Gets a string value from Redis. Returns {@code null} if the key does not exist.
     */
    public String get(String key) {
        try (Jedis jedis = jedisPool.getResource()) {
            return jedis.get(key);
        }
    }

    /**
     * Checks whether a key exists in Redis.
     */
    public boolean exists(String key) {
        try (Jedis jedis = jedisPool.getResource()) {
            return jedis.exists(key);
        }
    }

    /**
     * Deletes a key from Redis.
     */
    public void delete(String key) {
        try (Jedis jedis = jedisPool.getResource()) {
            jedis.del(key);
        }
    }

    /**
     * Atomically sets a key only if it does not already exist (SET NX).
     * Returns {@code true} if the key was set, {@code false} if it already existed.
     */
    public boolean setIfAbsent(String key, String value) {
        try (Jedis jedis = jedisPool.getResource()) {
            Long result = jedis.setnx(key, value);
            return result != null && result == 1L;
        }
    }
}
