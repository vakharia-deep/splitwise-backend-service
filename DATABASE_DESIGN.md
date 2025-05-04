# Splitwise Database Design

## Database Technology Choice

### Why PostgreSQL?

1. **Data Integrity and ACID Compliance**
   - Strong transactional support ensures data consistency
   - ACID properties are crucial for financial transactions
   - Reliable handling of concurrent operations
   - Built-in constraints and validations

2. **Relational Model Benefits**
   - Natural fit for our entity relationships
   - Efficient handling of complex joins
   - Strong data consistency through foreign keys
   - Well-defined schema prevents data anomalies

3. **Why Not NoSQL?**
   - Our data is highly structured and relational
   - Complex joins are frequent in our queries
   - Data consistency is critical for financial operations
   - Transaction support is essential for payment processing


## Overview
The Splitwise database is designed to handle expense sharing, group management, user relationships, and payment tracking. The design focuses on data integrity, query efficiency, and scalability.


### Core Entities

1. **Users**
   ```sql
   users (
     id: integer (PK)
     email: string (unique)
     password_hash: string
     name: string
     api_key: string (unique)
     api_key_expires_at: datetime
     inserted_at: datetime
     updated_at: datetime
   )
   ```

2. **Groups**
   ```sql
   groups (
     id: integer (PK)
     name: string
     description: string
     inserted_at: datetime
     updated_at: datetime
   )
   ```

3. **Group Members**
   ```sql
   group_members (
     id: integer (PK)
     group_id: integer (FK)
     user_id: integer (FK)
     inserted_at: datetime
     updated_at: datetime
   )
   ```

4. **Expenses**
   ```sql
   expenses (
     id: integer (PK)
     description: string
     amount: decimal
     date: date
     status: string
     paid_by_id: integer (FK)
     added_by_id: integer (FK)
     group_id: integer (FK)
     inserted_at: datetime
     updated_at: datetime
   )
   ```

5. **Expense Shares**
   ```sql
   expense_shares (
     id: integer (PK)
     expense_id: integer (FK)
     user_id: integer (FK)
     amount: decimal
     share_percentage: decimal
     remaining_amount: decimal
     status: string
     inserted_at: datetime
     updated_at: datetime
   )
   ```

6. **Payments**
   ```sql
   payments (
     id: integer (PK)
     amount: decimal
     status: string
     transaction_id: string (unique)
     from_user_id: integer (FK)
     to_user_id: integer (FK)
     expense_share_id: integer (FK)
     inserted_at: datetime
     updated_at: datetime
   )
   ```

7. **Comments**
   ```sql
   comments (
     id: integer (PK)
     content: string
     expense_id: integer (FK)
     user_id: integer (FK)
     inserted_at: datetime
     updated_at: datetime
   )
   ```

8. **Activity Logs**
   ```sql
   activity_logs (
     id: integer (PK)
     action: string
     user_id: integer (FK)
     entity_type: string
     entity_id: integer
     expense_id: integer (FK, nullable)
     group_id: integer (FK, nullable)
     payment_id: integer (FK, nullable)
     comment_id: integer (FK, nullable)
     details: jsonb
     inserted_at: datetime
   )
   ```

## Relationships

1. **Users to Groups (Many-to-Many)**
   - Through `group_members` join table
   - Allows users to be part of multiple groups
   - Enables group-based expense sharing

2. **Users to Expenses (One-to-Many)**
   - A user can create multiple expenses (`added_by_id`)
   - A user can pay for multiple expenses (`paid_by_id`)
   - Tracks who created and paid for each expense

3. **Groups to Expenses (One-to-Many)**
   - A group can have multiple expenses
   - Expenses must belong to a group
   - Enables group-based expense organization

4. **Expenses to Expense Shares (One-to-Many)**
   - An expense can have multiple shares
   - Each share represents a user's portion
   - Tracks individual contributions and debts

5. **Users to Expense Shares (One-to-Many)**
   - A user can have multiple expense shares
   - Tracks what each user owes or is owed
   - Enables individual balance calculations

6. **Expense Shares to Payments (One-to-Many)**
   - An expense share can have multiple payments
   - Tracks payment history for each share
   - Enables partial payments and settlements

7. **Users to Payments (One-to-Many)**
   - A user can make multiple payments (`from_user_id`)
   - A user can receive multiple payments (`to_user_id`)
   - Tracks payment flow between users

8. **Expenses to Comments (One-to-Many)**
   - An expense can have multiple comments
   - Enables discussion and clarification
   - Tracks user interactions with expenses

## Design Decisions and Rationale

### 1. Decimal for Monetary Values
- Used `decimal` type for all monetary values
- Ensures precise calculations without floating-point errors
- Important for financial transactions
- Maintains consistency across the application

### 2. Status Fields
- Added status fields to track state:
  - `expenses.status`: "pending", "settled"
  - `expense_shares.status`: "pending", "settled"
  - `payments.status`: "pending", "completed", "failed"
- Enables proper state management
- Helps in tracking payment progress
- Useful for reporting and analytics

### 3. Timestamps
- Included `inserted_at` and `updated_at` in all tables
- Helps in auditing and tracking changes
- Useful for debugging and monitoring
- Enables temporal queries

### 4. Activity Logging
- Separate `activity_logs` table for comprehensive tracking
- Uses JSONB for flexible details storage
- Tracks all important actions
- Enables audit trails and analytics

### 5. Indexing Strategy
- Primary keys on all tables
- Foreign key indexes for relationship fields
- Unique indexes on:
  - `users.email`
  - `users.api_key`
  - `payments.transaction_id`
- Composite indexes for common queries
- Improves query performance
- Maintains data integrity

### 6. Nullable Fields
- Carefully chosen nullable fields:
  - `activity_logs.expense_id`
  - `activity_logs.group_id`
  - `activity_logs.payment_id`
  - `activity_logs.comment_id`
- Allows flexible activity logging
- Reduces unnecessary joins
- Maintains data consistency

### 7. Share Percentage and Amount
- Both `share_percentage` and `amount` in expense_shares
- Enables flexible expense splitting
- Supports both percentage and fixed amount splits
- Maintains calculation accuracy

### 8. Remaining Amount Tracking
- `remaining_amount` in expense_shares
- Tracks outstanding balances
- Enables partial payments
- Simplifies balance calculations

## Performance Considerations

1. **Query Optimization**
   - Appropriate indexes for common queries
   - Efficient joins through proper relationships
   - Optimized balance calculations
   - Caching strategies for frequent queries

2. **Data Integrity**
   - Foreign key constraints
   - Unique constraints
   - Check constraints for status values
   - Transaction support for atomic operations

3. **Scalability**
   - Normalized schema for data consistency
   - Efficient indexing strategy
   - Partitioning considerations for large tables
   - Archival strategy for historical data

## Future Enhancements

1. **Additional Features**
   - Recurring expenses
   - Budget tracking
   - Category management
   - Currency support

2. **Performance Improvements**
   - Materialized views for common queries
   - Additional indexes for specific use cases
   - Query optimization
   - Caching strategies

3. **Data Management**
   - Data archival strategy
   - Backup and recovery procedures
   - Data migration tools
   - Monitoring and alerting 