-- Minimal reference schema for onboarding-pricing (active pricing selection)

-- Payments table (input)
CREATE TABLE payments (
    payment_id         VARCHAR,
    customer_id        VARCHAR,
    payment_method_id  VARCHAR,
    payment_date       DATE,      -- or TIMESTAMP depending on warehouse
    total_volume       DECIMAL(18,2)
);

-- Custom pricing table (customer-specific pricing)
CREATE TABLE custom_pricing (
    customer_id        VARCHAR,
    payment_method_id  VARCHAR,
    starts_at          DATE,
    ends_at            DATE,      -- NULL = open-ended
    fixed_rate         DECIMAL(10,4),
    variable_rate      DECIMAL(10,4)
);

-- Default pricing table (fallback per payment method)
CREATE TABLE default_pricing (
    payment_method_id  VARCHAR,
    starts_at          DATE,
    ends_at            DATE,      -- NULL = open-ended
    fixed_rate         DECIMAL(10,4),
    variable_rate      DECIMAL(10,4)
);
