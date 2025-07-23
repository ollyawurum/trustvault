;; Trust Vault - Decentralized Escrow Smart Contract
;; A secure, optimized escrow system with dispute resolution

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-ALREADY-EXISTS (err u402))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-STATUS (err u405))
(define-constant ERR-EXPIRED (err u406))
(define-constant ERR-INSUFFICIENT-FUNDS (err u407))
(define-constant ERR-INVALID-PARAMS (err u408))
(define-constant ERR-ALREADY-VOTED (err u409))

;; Fee configuration (0.5% = 50 basis points)
(define-constant PLATFORM-FEE-BASIS u50)
(define-constant BASIS-POINTS u10000)

;; Escrow statuses
(define-constant STATUS-PENDING u1)
(define-constant STATUS-FUNDED u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-DISPUTED u4)
(define-constant STATUS-REFUNDED u5)
(define-constant STATUS-RESOLVED u6)

;; Data Variables
(define-data-var escrow-nonce uint u0)
(define-data-var total-fees-collected uint u0)
(define-data-var emergency-timeout uint u5184000) ;; 60 days in blocks

;; Data Maps
(define-map escrows
    uint
    {
        buyer: principal,
        seller: principal,
        arbiter: principal,
        amount: uint,
        fee: uint,
        status: uint,
        created-at: uint,
        deadline: uint,
        description: (string-utf8 256)
    }
)

(define-map dispute-votes
    { escrow-id: uint, voter: principal }
    { vote-for-buyer: bool, timestamp: uint }
)

(define-map user-reputation
    principal
    { completed-deals: uint, disputed-deals: uint, total-volume: uint }
)

;; Read-only functions

(define-read-only (get-escrow (escrow-id uint))
    (map-get? escrows escrow-id)
)

(define-read-only (get-user-reputation (user principal))
    (default-to 
        { completed-deals: u0, disputed-deals: u0, total-volume: u0 }
        (map-get? user-reputation user)
    )
)

(define-read-only (calculate-fee (amount uint))
    (/ (* amount PLATFORM-FEE-BASIS) BASIS-POINTS)
)

(define-read-only (get-total-fees)
    (var-get total-fees-collected)
)

(define-read-only (has-voted (escrow-id uint) (voter principal))
    (is-some (map-get? dispute-votes { escrow-id: escrow-id, voter: voter }))
)

;; Private functions

(define-private (update-reputation (user principal) (is-completed bool) (amount uint))
    (let ((current-rep (get-user-reputation user)))
        (map-set user-reputation 
            user
            {
                completed-deals: (if is-completed 
                    (+ (get completed-deals current-rep) u1)
                    (get completed-deals current-rep)),
                disputed-deals: (if is-completed 
                    (get disputed-deals current-rep)
                    (+ (get disputed-deals current-rep) u1)),
                total-volume: (+ (get total-volume current-rep) amount)
            }
        )
    )
)

;; Public functions

(define-public (create-escrow (seller principal) (arbiter principal) (amount uint) (deadline uint) (description (string-utf8 256)))
    (let (
        (escrow-id (+ (var-get escrow-nonce) u1))
        (fee (calculate-fee amount))
        (total-amount (+ amount fee))
    )
        ;; Validations
        (asserts! (> amount u0) ERR-INVALID-PARAMS)
        (asserts! (> deadline burn-block-height) ERR-INVALID-PARAMS)
        (asserts! (not (is-eq tx-sender seller)) ERR-INVALID-PARAMS)
        (asserts! (not (is-eq tx-sender arbiter)) ERR-INVALID-PARAMS)
        (asserts! (not (is-eq seller arbiter)) ERR-INVALID-PARAMS)
        
        ;; Create escrow
        (map-set escrows 
            escrow-id
            {
                buyer: tx-sender,
                seller: seller,
                arbiter: arbiter,
                amount: amount,
                fee: fee,
                status: STATUS-PENDING,
                created-at: burn-block-height,
                deadline: deadline,
                description: description
            }
        )
        
        ;; Update nonce
        (var-set escrow-nonce escrow-id)
        
        (ok escrow-id)
    )
)

(define-public (fund-escrow (escrow-id uint))
    (let (
        (escrow (unwrap! (get-escrow escrow-id) ERR-NOT-FOUND))
        (total-amount (+ (get amount escrow) (get fee escrow)))
    )
        ;; Validations
        (asserts! (is-eq tx-sender (get buyer escrow)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status escrow) STATUS-PENDING) ERR-INVALID-STATUS)
        (asserts! (< burn-block-height (get deadline escrow)) ERR-EXPIRED)
        
        ;; Transfer funds to contract
        (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
        
        ;; Update status
        (map-set escrows 
            escrow-id
            (merge escrow { status: STATUS-FUNDED })
        )
        
        (ok true)
    )
)

(define-public (complete-escrow (escrow-id uint))
    (let (
        (escrow (unwrap! (get-escrow escrow-id) ERR-NOT-FOUND))
    )
        ;; Validations
        (asserts! (is-eq tx-sender (get buyer escrow)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status escrow) STATUS-FUNDED) ERR-INVALID-STATUS)
        
        ;; Transfer funds to seller
        (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get seller escrow))))
        
        ;; Collect platform fee
        (var-set total-fees-collected (+ (var-get total-fees-collected) (get fee escrow)))
        
        ;; Update status
        (map-set escrows 
            escrow-id
            (merge escrow { status: STATUS-COMPLETED })
        )
        
        ;; Update reputations
        (update-reputation (get buyer escrow) true (get amount escrow))
        (update-reputation (get seller escrow) true (get amount escrow))
        
        (ok true)
    )
)

(define-public (initiate-dispute (escrow-id uint))
    (let (
        (escrow (unwrap! (get-escrow escrow-id) ERR-NOT-FOUND))
    )
        ;; Validations
        (asserts! (or (is-eq tx-sender (get buyer escrow)) 
                     (is-eq tx-sender (get seller escrow))) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status escrow) STATUS-FUNDED) ERR-INVALID-STATUS)
        
        ;; Update status
        (map-set escrows 
            escrow-id
            (merge escrow { status: STATUS-DISPUTED })
        )
        
        (ok true)
    )
)

(define-public (vote-dispute (escrow-id uint) (vote-for-buyer bool))
    (let (
        (escrow (unwrap! (get-escrow escrow-id) ERR-NOT-FOUND))
    )
        ;; Validations
        (asserts! (is-eq (get status escrow) STATUS-DISPUTED) ERR-INVALID-STATUS)
        (asserts! (is-eq tx-sender (get arbiter escrow)) ERR-NOT-AUTHORIZED)
        (asserts! (not (has-voted escrow-id tx-sender)) ERR-ALREADY-VOTED)
        
        ;; Record vote
        (map-set dispute-votes 
            { escrow-id: escrow-id, voter: tx-sender }
            { vote-for-buyer: vote-for-buyer, timestamp: burn-block-height }
        )
        
        ;; Execute resolution
        (if vote-for-buyer
            ;; Refund to buyer
            (begin
                (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get buyer escrow))))
                (map-set escrows escrow-id (merge escrow { status: STATUS-REFUNDED }))
                (update-reputation (get seller escrow) false (get amount escrow))
            )
            ;; Release to seller
            (begin
                (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get seller escrow))))
                (map-set escrows escrow-id (merge escrow { status: STATUS-RESOLVED }))
                (update-reputation (get buyer escrow) false (get amount escrow))
            )
        )
        
        ;; Collect platform fee
        (var-set total-fees-collected (+ (var-get total-fees-collected) (get fee escrow)))
        
        (ok true)
    )
)

(define-public (emergency-withdraw (escrow-id uint))
    (let (
        (escrow (unwrap! (get-escrow escrow-id) ERR-NOT-FOUND))
        (timeout-block (+ (get created-at escrow) (var-get emergency-timeout)))
    )
        ;; Validations
        (asserts! (is-eq tx-sender (get buyer escrow)) ERR-NOT-AUTHORIZED)
        (asserts! (or (is-eq (get status escrow) STATUS-FUNDED)
                     (is-eq (get status escrow) STATUS-DISPUTED)) ERR-INVALID-STATUS)
        (asserts! (> burn-block-height timeout-block) ERR-INVALID-PARAMS)
        
        ;; Refund to buyer after timeout
        (try! (as-contract (stx-transfer? (+ (get amount escrow) (get fee escrow)) tx-sender (get buyer escrow))))
        
        ;; Update status
        (map-set escrows 
            escrow-id
            (merge escrow { status: STATUS-REFUNDED })
        )
        
        (ok true)
    )
)

(define-public (withdraw-fees (recipient principal))
    (let (
        (fees (var-get total-fees-collected))
    )
        ;; Only contract owner can withdraw fees
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> fees u0) ERR-INSUFFICIENT-FUNDS)
        
        ;; Transfer fees
        (try! (as-contract (stx-transfer? fees tx-sender recipient)))
        
        ;; Reset counter
        (var-set total-fees-collected u0)
        
        (ok fees)
    )
)

(define-public (update-emergency-timeout (new-timeout uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> new-timeout u0) ERR-INVALID-PARAMS)
        (var-set emergency-timeout new-timeout)
        (ok true)
    )
)