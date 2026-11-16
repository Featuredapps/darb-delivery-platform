import { Module } from '@nestjs/common';
import { DriversController } from './drivers.controller';
import { DriversService } from './drivers.service';
import { DriverStatusController } from './driver-status.controller';
@Module({controllers:[DriversController,DriverStatusController],providers:[DriversService]})
export class DriversModule {}
