# Educational Feedback Registry

## Decentralized Course Evaluation System

The Educational Feedback Registry is a smart contract built on the Stacks blockchain that enables educational institutions to gather, store, and manage student feedback on courses in a decentralized and transparent manner.

## Overview

This smart contract provides a comprehensive system for:
- Course management by administrators
- Instructor assignment
- Student enrollment
- Course evaluation submission by students
- Feedback tracking and retrieval

## Key Features

- **Decentralized Transparency**: All feedback is stored on-chain for permanent, tamper-proof record-keeping
- **Role-Based Access Control**: Clear separation between admin, instructor, and student permissions
- **Privacy Considerations**: Students can submit evaluations tied to their blockchain identity
- **Active Course Management**: Courses can be marked as active or inactive

## Contract Structure

The smart contract implements several key data structures:

1. **Course Registry**: Stores course metadata including title, instructor, and active status
2. **Evaluation Registry**: Maps student/course combinations to submitted evaluations
3. **Student Enrollment Registry**: Tracks which students are enrolled in which courses

## Functions

### Administrative Functions

- `create-new-course`: Creates a new course (admin only)
- `assign-course-instructor`: Assigns a new instructor to a course (admin only)
- `update-course-status`: Activates or deactivates a course (admin or instructor)

### Instructor Functions

- `register-student`: Enrolls a student in a course (admin or instructor)

### Student Functions

- `submit-course-evaluation`: Submits rating and feedback for a course (enrolled students only)

### Read-Only Functions

- `get-course-details`: Retrieves course information
- `check-student-enrollment`: Verifies if a student is enrolled in a course
- `get-student-evaluation`: Retrieves a student's evaluation for a course
- `calculate-course-average-rating`: Calculates average rating (placeholder implementation)
- `is-admin`: Checks if caller is administrator
- `is-course-instructor`: Checks if caller is course instructor
- `can-manage-course`: Checks if caller can manage a course

## Error Handling

The contract includes comprehensive error codes for clear feedback:

- `ERR-ADMIN-ONLY (u100)`: Operation restricted to administrators
- `ERR-COURSE-NOT-FOUND (u101)`: Requested course doesn't exist
- `ERR-COURSE-ALREADY-EXISTS (u102)`: Course ID already in use
- `ERR-UNAUTHORIZED-ACCESS (u103)`: Caller lacks necessary permissions
- `ERR-INVALID-RATING-RANGE (u104)`: Rating outside acceptable range (1-5)
- `ERR-DUPLICATE-FEEDBACK-SUBMISSION (u105)`: Student already submitted feedback
- `ERR-STUDENT-NOT-ENROLLED (u106)`: Student not enrolled in course
- `ERR-COURSE-INACTIVE (u107)`: Course not currently active

## Usage Examples

### Creating a New Course (Admin)

```clarity
;; As admin
(contract-call? .educational-feedback-registry create-new-course "Introduction to Blockchain")
```

### Enrolling a Student (Instructor)

```clarity
;; As instructor
(contract-call? .educational-feedback-registry register-student u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Submitting Course Evaluation (Student)

```clarity
;; As enrolled student
(contract-call? .educational-feedback-registry submit-course-evaluation u1 u4 "Great course with excellent materials!")
```

## Deployment Notes

1. The contract deployer automatically becomes the system administrator
2. Course IDs are assigned sequentially starting from 1
3. Rating scale is 1-5 (whole numbers only)
4. Feedback comments are limited to 500 characters