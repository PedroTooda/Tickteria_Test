export const TicketStatus = {
  ISSUED: 'ISSUED',
  VOIDED: 'VOIDED',
  USED: 'USED',
} as const;
export type TicketStatus = (typeof TicketStatus)[keyof typeof TicketStatus];
