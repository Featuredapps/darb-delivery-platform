import { Module } from '@nestjs/common';
import { AiRoleAssistantController } from './ai-role-assistant.controller';
import { AiRoleAssistantService } from './ai-role-assistant.service';

@Module({ controllers: [AiRoleAssistantController], providers: [AiRoleAssistantService] })
export class AiRoleAssistantModule {}
