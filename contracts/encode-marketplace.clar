;; Encode Marketplace
;; 
;; A decentralized protocol for secure, transparent, and efficient job matching
;; This contract manages job lifecycles, payments, and dispute resolution

;; Error Codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-RESOURCE-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATE (err u102))
(define-constant ERR-FUNDS-INSUFFICIENT (err u103))
(define-constant ERR-PROPOSAL-CONFLICT (err u104))
(define-constant ERR-USER-CONFLICT (err u105))
(define-constant ERR-ALREADY-EXISTS (err u106))
(define-constant ERR-DEADLINE-EXCEEDED (err u115))

;; Job Status Definitions
(define-constant STATUS-PENDING u1)
(define-constant STATUS-IN-PROGRESS u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-TERMINATED u4)
(define-constant STATUS-CONTESTED u5)

;; Platform Configuration
(define-constant PLATFORM-FEE-BASIS-POINTS u25) ;; 2.5%

;; Contract Owner Management
(define-data-var contract-administrator principal tx-sender)

;; Data Maps for Tracking
(define-map job-registry
  { job-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-utf8 1000),
    total-budget: uint,
    remaining-budget: uint,
    expiration-block: uint,
    current-status: uint,
    assigned-worker: (optional principal)
  }
)

(define-map worker-proposals
  { job-id: uint, worker: principal }
  {
    proposal-details: (string-utf8 500),
    proposed-compensation: uint,
    proposed-timeline: uint,
    submission-block: uint
  }
)

(define-map work-milestones
  { job-id: uint, milestone-id: uint }
  {
    description: (string-utf8 200),
    allocation: uint,
    payment-status: bool,
    completion-timestamp: (optional uint)
  }
)

(define-map dispute-records
  { job-id: uint }
  {
    initiator: principal,
    dispute-reason: (string-utf8 500),
    client-evidence: (optional (string-utf8 1000)),
    worker-evidence: (optional (string-utf8 1000)),
    appointed-resolver: (optional principal),
    resolution-status: bool,
    resolution-summary: (optional (string-utf8 500)),
    dispute-timestamp: uint
  }
)

;; Counters and Utility Variables
(define-data-var next-job-identifier uint u0)
(define-data-var platform-treasury principal tx-sender)

;; Private Utility Functions
(define-private (increment-job-counter)
  (let ((current-count (var-get next-job-identifier)))
    (var-set next-job-identifier (+ current-count u1))
    current-count
  )
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount PLATFORM-FEE-BASIS-POINTS) u1000)
)

;; Public Functions for Job Management
(define-public (create-job
  (job-title (string-ascii 100))
  (job-description (string-utf8 1000))
  (total-budget uint)
  (expiration-block uint)
)
  (let (
    (job-id (increment-job-counter))
    (job-creator tx-sender)
  )
    ;; Input validation
    (asserts! (> total-budget u0) ERR-FUNDS-INSUFFICIENT)
    (asserts! (> expiration-block block-height) ERR-DEADLINE-EXCEEDED)
    
    ;; Transfer budget to contract
    (try! (stx-transfer? total-budget job-creator (as-contract tx-sender)))
    
    ;; Register job
    (map-set job-registry
      { job-id: job-id }
      {
        creator: job-creator,
        title: job-title,
        description: job-description,
        total-budget: total-budget,
        remaining-budget: total-budget,
        expiration-block: expiration-block,
        current-status: STATUS-PENDING,
        assigned-worker: none
      }
    )
    
    (ok job-id)
  )
)

(define-public (submit-work-proposal
  (job-id uint)
  (proposal-text (string-utf8 500))
  (proposed-compensation uint)
  (proposed-timeline uint)
)
  (let (
    (worker tx-sender)
    (job-details (map-get? job-registry { job-id: job-id }))
  )
    ;; Validation checks
    (asserts! (is-some job-details) ERR-RESOURCE-NOT-FOUND)
    (asserts! (is-eq (get current-status (unwrap-panic job-details)) STATUS-PENDING) ERR-INVALID-STATE)
    (asserts! (<= proposed-compensation (get total-budget (unwrap-panic job-details))) ERR-FUNDS-INSUFFICIENT)
    (asserts! (> proposed-timeline block-height) ERR-DEADLINE-EXCEEDED)
    
    ;; Prevent duplicate proposals
    (asserts! (is-none (map-get? worker-proposals { job-id: job-id, worker: worker })) ERR-PROPOSAL-CONFLICT)
    
    ;; Record proposal
    (map-set worker-proposals
      { job-id: job-id, worker: worker }
      {
        proposal-details: proposal-text,
        proposed-compensation: proposed-compensation,
        proposed-timeline: proposed-timeline,
        submission-block: block-height
      }
    )
    
    (ok true)
  )
)

;; More functions would follow similar pattern