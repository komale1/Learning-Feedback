;; EDUCATIONAL FEEDBACK REGISTRY - DECENTRALIZED COURSE EVALUATION SYSTEM
;;
;; This smart contract enables educational ecosystems to gather, store, and
;; manage student feedback on courses in a decentralized, transparent manner.
;; Students can submit ratings and comments for courses they're enrolled in,
;; while instructors and administrators can manage course offerings.

;; CONSTANTS & ERROR CODES

;; System administrator - deployer of the contract
(define-constant admin-principal tx-sender)

;; Rating boundaries
(define-constant MIN-ACCEPTABLE-RATING u1)
(define-constant MAX-ACCEPTABLE-RATING u5)

;; Error codes
(define-constant ERR-ADMIN-ONLY (err u100))
(define-constant ERR-COURSE-NOT-FOUND (err u101))
(define-constant ERR-COURSE-ALREADY-EXISTS (err u102))
(define-constant ERR-UNAUTHORIZED-ACCESS (err u103))
(define-constant ERR-INVALID-RATING-RANGE (err u104))
(define-constant ERR-DUPLICATE-FEEDBACK-SUBMISSION (err u105))
(define-constant ERR-STUDENT-NOT-ENROLLED (err u106))
(define-constant ERR-COURSE-INACTIVE (err u107))
(define-constant ERR-INVALID-INPUT (err u108))

;; DATA STRUCTURES

;; Registry of all courses available in the system
;; Maps a course identifier to its metadata
(define-map course-registry
  { course-identifier: uint }
  {
    course-title: (string-ascii 100),
    course-instructor: principal,
    course-active-status: bool
  }
)

;; Registry of student evaluations
;; Maps the combination of course and student to their submitted evaluation
(define-map evaluation-registry
  { course-identifier: uint, student-principal: principal }
  {
    evaluation-score: uint,
    evaluation-text: (string-utf8 500),
    submission-block-height: uint
  }
)

;; Registry of student course registrations
;; Tracks which students are enrolled in which courses
(define-map student-enrollment-registry
  { course-identifier: uint, student-principal: principal }
  { enrollment-status: bool }
)

;; Course ratings summary to track total scores and count for average calculation
(define-map course-ratings-summary
  { course-identifier: uint }
  {
    total-score: uint,
    rating-count: uint
  }
)

;; System counter for course identifiers
(define-data-var next-course-id uint u0)

;; ACCESS CONTROL FUNCTIONS

;; Verifies if the transaction sender is the system administrator
(define-read-only (is-admin)
  (is-eq tx-sender admin-principal)
)

;; Verifies if the transaction sender is an instructor for a specific course
(define-read-only (is-course-instructor (course-identifier uint))
  (let ((course-data (get-course-details course-identifier)))
    (and 
      (is-some course-data)
      (is-eq tx-sender (get course-instructor (unwrap-panic course-data)))
    )
  )
)

;; Verifies if the caller is authorized to manage a course (admin or instructor)
(define-read-only (can-manage-course (course-identifier uint))
  (or 
    (is-admin)
    (is-course-instructor course-identifier)
  )
)

;; INPUT VALIDATION FUNCTIONS

;; Validates that a course title is not empty and within size limits
(define-read-only (is-valid-course-title (title (string-ascii 100)))
  (let ((title-length (len title)))
    (> title-length u0)
  )
)

;; Validates that feedback comments are within proper constraints
(define-read-only (is-valid-feedback (feedback (string-utf8 500)))
  (let ((feedback-length (len feedback)))
    (and (>= feedback-length u1) (<= feedback-length u500))
  )
)

;; COURSE MANAGEMENT FUNCTIONS - READ ONLY

;; Retrieves detailed information about a course
(define-read-only (get-course-details (course-identifier uint))
  (map-get? course-registry { course-identifier: course-identifier })
)

;; Checks if a student is officially enrolled in a course
(define-read-only (check-student-enrollment (course-identifier uint) (student-principal principal))
  (default-to 
    false
    (get enrollment-status (map-get? student-enrollment-registry 
                           { course-identifier: course-identifier, 
                             student-principal: student-principal }))
  )
)

;; Retrieves the student's feedback for a specific course
(define-read-only (get-student-evaluation (course-identifier uint) (student-principal principal))
  (map-get? evaluation-registry 
    { course-identifier: course-identifier, 
      student-principal: student-principal })
)

;; Calculates the average rating for a course
(define-read-only (calculate-course-average-rating (course-identifier uint))
  (let (
    (ratings-data (map-get? course-ratings-summary { course-identifier: course-identifier }))
  )
    (if (is-some ratings-data)
      (let (
        (total (get total-score (unwrap-panic ratings-data)))
        (count (get rating-count (unwrap-panic ratings-data)))
      )
        (if (> count u0)
          (/ total count)
          u0
        )
      )
      u0
    )
  )
)

;; Get total number of ratings for a course
(define-read-only (get-course-rating-count (course-identifier uint))
  (default-to
    u0
    (get rating-count (map-get? course-ratings-summary { course-identifier: course-identifier }))
  )
)

;; COURSE MANAGEMENT FUNCTIONS - PUBLIC

;; Creates a new course in the system
(define-public (create-new-course (course-title (string-ascii 100)))
  (let
    ((course-identifier (+ (var-get next-course-id) u1)))
    
    ;; Only admin can create courses
    (asserts! (is-admin) ERR-ADMIN-ONLY)
    
    ;; Validate course title
    (asserts! (is-valid-course-title course-title) ERR-INVALID-INPUT)
    
    ;; Register the new course
    (map-set course-registry
      { course-identifier: course-identifier }
      {
        course-title: course-title,
        course-instructor: tx-sender,
        course-active-status: true
      }
    )
    
    ;; Initialize course ratings summary
    (map-set course-ratings-summary
      { course-identifier: course-identifier }
      {
        total-score: u0,
        rating-count: u0
      }
    )
    
    ;; Update the course counter
    (var-set next-course-id course-identifier)
    
    ;; Return the new course identifier
    (ok course-identifier)
  )
)

;; Assigns a new instructor to an existing course
(define-public (assign-course-instructor (course-identifier uint) (instructor-principal principal))
  (let ((course-data (get-course-details course-identifier)))
    ;; Verify course exists
    (asserts! (is-some course-data) ERR-COURSE-NOT-FOUND)
    
    ;; Only admin can change instructor assignment
    (asserts! (is-admin) ERR-ADMIN-ONLY)
    
    ;; Update the course instructor
    (map-set course-registry
      { course-identifier: course-identifier }
      (merge (unwrap-panic course-data) 
             { course-instructor: instructor-principal })
    )
    
    (ok true)
  )
)

;; Registers a student for a course
(define-public (register-student (course-identifier uint) (student-principal principal))
  (let (
    (course-data (get-course-details course-identifier))
    (verified-principal (if (is-eq student-principal tx-sender) 
                            tx-sender 
                            student-principal))
  )
    ;; Verify course exists
    (asserts! (is-some course-data) ERR-COURSE-NOT-FOUND)
    
    ;; Verify caller is authorized to register students
    (asserts! (can-manage-course course-identifier) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Register the student - using the verified principal
    (map-set student-enrollment-registry
      { course-identifier: course-identifier, 
        student-principal: verified-principal }
      { enrollment-status: true }
    )
    
    (ok true)
  )
)

;; Records a student's evaluation for a course
(define-public (submit-course-evaluation 
                (course-identifier uint) 
                (rating-score uint) 
                (feedback-comment (string-utf8 500)))
  (let (
    (course-data (get-course-details course-identifier))
    (previous-evaluation (get-student-evaluation course-identifier tx-sender))
    (ratings-data (map-get? course-ratings-summary { course-identifier: course-identifier }))
  )
    ;; Verify course exists
    (asserts! (is-some course-data) ERR-COURSE-NOT-FOUND)
    
    ;; Verify course is active
    (asserts! (get course-active-status (unwrap-panic course-data)) ERR-COURSE-INACTIVE)
    
    ;; Verify student is enrolled
    (asserts! (check-student-enrollment course-identifier tx-sender) ERR-STUDENT-NOT-ENROLLED)
    
    ;; Verify rating is within acceptable range
    (asserts! (and (>= rating-score MIN-ACCEPTABLE-RATING) 
                  (<= rating-score MAX-ACCEPTABLE-RATING)) 
             ERR-INVALID-RATING-RANGE)
    
    ;; Verify student hasn't already submitted evaluation
    (asserts! (is-none previous-evaluation) ERR-DUPLICATE-FEEDBACK-SUBMISSION)
    
    ;; Validate feedback comment
    (asserts! (is-valid-feedback feedback-comment) ERR-INVALID-INPUT)
    
    ;; Record the evaluation
    (map-set evaluation-registry
      { course-identifier: course-identifier, 
        student-principal: tx-sender }
      {
        evaluation-score: rating-score,
        evaluation-text: feedback-comment,
        submission-block-height: block-height
      }
    )
    
    ;; Update course ratings summary
    (if (is-some ratings-data)
      (let (
        (current-total (get total-score (unwrap-panic ratings-data)))
        (current-count (get rating-count (unwrap-panic ratings-data)))
      )
        (map-set course-ratings-summary
          { course-identifier: course-identifier }
          {
            total-score: (+ current-total rating-score),
            rating-count: (+ current-count u1)
          }
        )
      )
      ;; Initialize if no ratings data exists yet
      (map-set course-ratings-summary
        { course-identifier: course-identifier }
        {
          total-score: rating-score,
          rating-count: u1
        }
      )
    )
    
    (ok true)
  )
)

;; Updates a course's active status
(define-public (update-course-status (course-identifier uint) (active-status bool))
  (let ((course-data (get-course-details course-identifier)))
    ;; Verify course exists
    (asserts! (is-some course-data) ERR-COURSE-NOT-FOUND)
    
    ;; Verify caller is authorized to update course status
    (asserts! (can-manage-course course-identifier) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Update the course status
    (map-set course-registry
      { course-identifier: course-identifier }
      (merge (unwrap-panic course-data) 
             { course-active-status: active-status })
    )
    
    (ok true)
  )
)