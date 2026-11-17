import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
@Injectable()
export class AddressesService {
  constructor(private readonly prisma: PrismaService) {}
  list(userId: string) { return this.prisma.address.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } }); }
  async create(userId: string, dto: { label?: string; details: string; latitude?: number; longitude?: number }) {
    if ((dto.latitude === undefined) !== (dto.longitude === undefined)) throw new BadRequestException('يجب إرسال خط العرض والطول معاً');
    const address = await this.prisma.address.create({ data: { userId, label: dto.label, details: dto.details } });
    if (dto.latitude !== undefined && dto.longitude !== undefined) {
      await this.prisma.$executeRaw`UPDATE "Address" SET "point" = ST_SetSRID(ST_MakePoint(${dto.longitude}, ${dto.latitude}), 4326)::geography WHERE "id" = ${address.id} AND "userId" = ${userId}`;
    }
    return this.prisma.address.findUnique({ where: { id: address.id } });
  }
}
