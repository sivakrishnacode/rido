import { IsIn, IsString } from 'class-validator';

/** POST /subscriptions body (D-12a). */
export class PurchasePlanDto {
  @IsString()
  planId: string;

  @IsIn(['GPay', 'PhonePe', 'Paytm', 'BHIM'])
  upiApp: string;
}
