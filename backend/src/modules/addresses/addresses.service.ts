import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
@Injectable()
export class AddressesService {
  constructor(private readonly prisma:PrismaService){}
  list(userId:string){return this.prisma.address.findMany({where:{userId},orderBy:{createdAt:'desc'}});}
  async create(userId:string,dto:{label?:string;details:string;latitude?:number;longitude?:number}) {
    if ((dto.latitude === undefined) !== (dto.longitude === undefined)) {
      throw new BadRequestException('يجب إرسال خط العرض وخط الطول معاً');
    }
    return this.prisma.$transaction(async tx => {
      const address = await tx.address.create({data:{userId,label:dto.label,details:dto.details}});
      if (dto.latitude !== undefined && dto.longitude !== undefined) {
        await tx.$executeRaw`UPDATE "Address" SET point = ST_SetSRID(ST_MakePoint(${dto.longitude}, ${dto.latitude}), 4326)::geography WHERE id = ${address.id}`;
      }
      return tx.address.findUnique({where:{id:address.id}});
    });
  }
}
