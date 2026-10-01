import * as React from 'react'
import { Slot } from '@radix-ui/react-slot'

import { cn } from '@/lib/utils'

const ModalPortal = ({ children }: { children: React.ReactNode }) => {
  return ReactDOM.createPortal(
    <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
      <div className="relative w-full max-w-md max-h-[90vh] overflow-y-auto">
        <div className="bg-white rounded-lg p-6 shadow-lg">
          {children}
        </div>
      </div>
    </div>,
    document.body,
  )
}

const ModalOverlay = React.forwardRef<
  HTMLElement,
  React.ButtonHTMLAttributes<HTMLButtonElement>
>(({ className, ...props }, ref) => (
  <button
    ref={ref}
    className={cn(
      'fixed inset-0 z-50 bg-black/50 backdrop-blur-sm',
      className,
    )}
    aria-label="Close"
    {...props}
  />
))
ModalOverlay.displayName = 'ModalOverlay'

const ModalContent = React.forwardRef<
  HTMLElement,
  React.ButtonHTMLAttributes<HTMLButtonElement>
>(({ className, children, ...props }, ref) => (
  <div
    ref={ref}
    className={cn(
      'relative bg-white rounded-lg shadow-md w-full max-w-lg p-6',
      className,
    )}
    {...props}
  >
    <Slot className="space-y-6">{children}</Slot>
  </div>
))
ModalContent.displayName = 'ModalContent'

const ModalHeader = React.forwardRef<
  HTMLElement,
  React.HTMLAttributes<HTMLElement>
>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={cn('flex flex-col space-y-2 text-center sm:text-left', className)}
    {...props}
  >
    <Slot />
  </div>
))
ModalHeader.displayName = 'ModalHeader'

const ModalTitle = React.forwardRef<
  HTMLElement,
  React.HTMLAttributes<HTMLElement>
>(({ className, ...props }, ref) => (
  <h2
    ref={ref}
    className={cn(
      'text-xl font-semibold leading-none tracking-tight',
      className,
    )}
    {...props}
  >
    <Slot />
  </h2>
))
ModalTitle.displayName = 'ModalTitle'

const ModalDescription = React.forwardRef<
  HTMLElement,
  React.HTMLAttributes<HTMLElement>
>(({ className, ...props }, ref) => (
  <p
    ref={ref}
    className={cn('text-muted-foreground', className)}
    {...props}
  >
    <Slot />
  </p>
))
ModalDescription.displayName = 'ModalDescription'

const ModalFooter = React.forwardRef<
  HTMLElement,
  React.HTMLAttributes<HTMLElement>
>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={cn('flex flex-col-reverse sm:flex-row sm:space-x-2 sm:justify-end', className)}
    {...props}
  >
    <Slot />
  </div>
))
ModalFooter.displayName = 'ModalFooter'

export {
  ModalPortal,
  ModalOverlay,
  ModalContent,
  ModalHeader,
  ModalTitle,
  ModalDescription,
  ModalFooter,
}