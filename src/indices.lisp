(in-package :coleslaw)

(defclass index ()
  ((id :initform nil :initarg :id :accessor index-id)
   (posts :initform nil :initarg :posts :accessor index-posts)
   (title :initform nil :initarg :title :accessor index-title)))

(defmethod render ((object index) &key prev next)
  (funcall (theme-fn 'index) (list :tags (all-tags)
                                   :months (all-months)
                                   :config *config*
                                   :index object
                                   :prev prev
                                   :next next)))

(defclass tag-index (index) ())
(defclass date-index (index) ())
(defclass int-index (index) ())

(defmethod page-path ((object index))
  (rel-path (staging *config*) (index-id object)))
(defmethod page-path ((object tag-index))
  (rel-path (staging *config*) "tag/~a" (index-id object)))
(defmethod page-path ((object date-index))
  (rel-path (staging *config*) "date/~a" (index-id object)))
(defmethod page-path ((object int-index))
  (rel-path (staging *config*) "~d" (index-id object)))

(defun all-months ()
  "Retrieve a list of all months with published content."
  (sort (remove-duplicates (mapcar (lambda (x) (get-month (content-date x)))
                                   (hash-table-values *content*)) :test #'string=)
        #'string>))

(defun all-tags ()
  "Retrieve a list of all tags used in content."
  (sort (remove-duplicates (mappend 'content-tags (hash-table-values *content*))
                           :test #'string=) #'string<))

(defun get-month (timestamp)
  "Extract the YYYY-MM portion of TIMESTAMP."
  (subseq timestamp 0 7))

(defun index-by-tag (tag content)
  "Return an index of all CONTENT matching the given TAG."
  (let ((results (remove-if-not (lambda (obj) (member tag (content-tags obj)
                                                      :test #'string=)) content)))
    (make-instance 'tag-index :id tag
                              :posts results
                              :title (format nil "Posts tagged ~a" tag))))

(defun index-by-month (month content)
  "Return an index of all CONTENT matching the given MONTH."
  (let ((results (remove-if-not (lambda (obj) (search month (content-date obj)))
                                content)))
    (make-instance 'date-index :id month
                               :posts results
                               :title (format nil "Posts from ~a" month))))

(defun index-by-n (i content &optional (step 10))
  "Return the index for the Ith page of CONTENT in reverse chronological order."
  (make-instance 'int-index :id (1+ i)
                            :posts (let ((index (* step i)))
                                     (subseq content index (min (length content)
                                                                (+ index step))))
                            :title "Recent Posts"))

(defun render-indices ()
  "Render the indices to view content in groups of size N, by month, and by tag."
  (let ((results (by-date (hash-table-values *content*))))
    (dolist (tag (all-tags))
      (let ((index (index-by-tag tag results)))
        (write-page (page-path index) (render-page index))))
    (dolist (month (all-months))
      (let ((index (index-by-month month results)))
        (write-page (page-path index) (render-page index))))
    (dotimes (i (ceiling (length results) 10))
      (let ((index (index-by-n i results)))
        (write-page (page-path index)
                    (render-page index nil
                                 :prev (and (plusp i) i)
                                 :next (and (< (* (1+ i) 10) (length results))
                                            (+ 2 i)))))))
  (update-symlink "index.html" "1.html"))
