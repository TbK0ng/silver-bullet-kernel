## ADDED Requirements

### Requirement: Demo Service Health Endpoint

The demo service SHALL expose a health endpoint for runtime checks.

#### Scenario: Health check returns service metadata

- **WHEN** a client requests `GET /health`
- **THEN** the service returns HTTP 200
- **AND** response includes `status` and `service` fields

### Requirement: Demo Task CRUD Slice

The demo service SHALL provide create, list, and update operations for tasks.

#### Scenario: Create a task

- **WHEN** a client sends `POST /api/tasks` with a valid `title`
- **THEN** the service returns HTTP 201
- **AND** response contains an identifier, timestamps, and `done=false`

#### Scenario: List tasks

- **WHEN** a client sends `GET /api/tasks`
- **THEN** the service returns HTTP 200
- **AND** response contains `count` and `items`

#### Scenario: Update a task

- **WHEN** a client sends `PATCH /api/tasks/:id` with valid fields
- **THEN** the service returns HTTP 200 and updated task values

#### Scenario: Unknown task update fails

- **WHEN** a client updates a non-existent task id
- **THEN** the service returns HTTP 404 with error `TASK_NOT_FOUND`

### Requirement: Input Validation

The demo service SHALL validate request payloads and task identifiers.

#### Scenario: Invalid payload is rejected

- **WHEN** a request omits required fields or sends invalid types
- **THEN** the service returns HTTP 400
- **AND** response includes validation details
