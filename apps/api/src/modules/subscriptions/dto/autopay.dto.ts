import { IsIn } from 'class-validator';

/** POST /subscriptions/me/autopay body (D-12: set up UPI Autopay during the free trial). */
export class AutopayDto {
  @IsIn(['GPay', 'PhonePe', 'Paytm', 'BHIM'])
  upiApp: string;
}
