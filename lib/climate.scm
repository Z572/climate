;;; -*- mode:scheme; coding:utf-8; -*-
;;;
;;; Copyright 2024 Takashi Kato <ktakshi@ymail.com>
;;; 
;;; Licensed under the Apache License, Version 2.0 (the "License");
;;; you may not use this file except in compliance with the License.
;;; You may obtain a copy of the License at
;;; 
;;;     http://www.apache.org/licenses/LICENSE-2.0
;;; 
;;; Unless required by applicable law or agreed to in writing, software
;;; distributed under the License is distributed on an "AS IS" BASIS,
;;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;;; See the License for the specific language governing permissions and
;;; limitations under the License.
;;;

(library (climate)
    (export climate group arguments options prefab climate:command
	    climate? climate-commands climate-command
	    describe-climate-usage
	    execute-climate
	    command-group? command-group-commands
	    command-executor? command-executor-process
	    result? result-success? result-value

	    ;; command line input utilities
	    argument->input-port
	    argument->string-content
	    argument->bytevector-content
	    call-with-argument-input-port
	    parse-attributed-argument
	    )
    (import (rnrs)
	    (climate dsl)
	    (climate types)
	    (climate input))

(define (execute-climate climate args)
  (cond ((null? args) (climate-usage-result climate "No command is given" #f))
	((climate-command climate (string->symbol (car args))) =>
	 (lambda (command)
	   (execute-command (list (climate-name climate)) command (cdr args))))
	(else (climate-usage-result climate "Command not found" (car args)))))

(define (climate-usage-result climate message irr)
  (let-values (((out e) (open-string-output-port)))
    (display "Error: " out) (display message out)
    (when irr (display " " out) (display irr out))
    (newline out)
    (newline out)
    (describe-climate-usage climate out)
    (make-error-result (e))))

(define (describe-climate-usage climate out)
  (display "Usage:" out)
  (newline out)
  ;; $ name command [sub-command ...] [options ...]
  (display "$ " out)
  (display (climate-name climate) out)
  (display " command [sub-command ...] [options ...]" out)
  (newline out)
  (newline out)
  ;; list of available commands
  (display "COMMANDS:" out) (newline out)
  (for-each (lambda (command)
	      (display "  - " out)
	      (display (command-name command) out)
	      (cond ((command-usage command) =>
		     (lambda (usage)
		       (cond ((string? usage)
			      (display ": " out) (display usage out))
			     ((and (pair? usage) (car usage))
			      (display ": " out) (display (car usage) out))))))
	      (newline out))
	    (climate-commands climate)))
  

(define (execute-command exec-tree command args)
  (define (format-message c)
    (let-values (((o e) (open-string-output-port)))
      (put-string o (condition-message c))
      (put-string o ": ")
      (cond ((and (irritants-condition? c) (condition-irritants c)) =>
	     (lambda (irr)
	       (for-each (lambda (i) (display i o) (display " ")) irr)))
	    ((and (i/o-filename-error? c) (i/o-error-filename c)) =>
	     (lambda (file) (put-string o file))))
      (e)))
		      
  (cond ((command-executor? command)
	 ;; TODO args to options
	 (guard (e (else (command-usage-result command exec-tree
					       (format-message e)
					       args)))
	   (make-success-result
	    (invoke-command-executor command exec-tree args))))
	((command-group? command)
	 (cond ((null? args)
		(command-usage-result command exec-tree
				      "No sub command is given" #f))
	       ((command-group-command command (string->symbol (car args))) =>
		(lambda (cmd)
		  (execute-command (cons (command-name command) exec-tree)
				   cmd (cdr args))))
	       (else (command-usage-result command exec-tree
					   "Command not found" (car args)))))
	(else (make-error-result "[BUG] unknown command"))))

(define (command-usage-result command tree msg irr)
  (let-values (((out e) (open-string-output-port)))
    (display "Error: " out) (display msg out)
    (when irr (display " " out) (display irr out))
    (newline out)
    (newline out)

    (let ((usage (cond ((command-group? command)
			(command-group-usage command tree))
		       (else
			(command-executor-usage command tree)))))
      (display usage out)
      (make-error-result (e)))))

)
